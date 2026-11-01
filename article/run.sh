#!/bin/bash
#  Benchmark of BME280 compensation formulas: Bosch C (double, 64-bit and
#  32-bit integer) versus Ada fixed point types (reznikmm/bme280).
#
#  1. Accuracy on x86_64 (native GNAT), the double version is the reference.
#  2. Code size and instruction mix for Cortex-M4F (STM32F4) with GNAT arm-elf.
#
#  Toolchains are taken from GNAT_NATIVE_DIRECTORY and GNAT_ARM_DIRECTORY,
#  if they are not set, GNAT FSF 16.1 builds are downloaded from GitHub.
set -e

WORK_DIRECTORY=$(pwd)/work
SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
RELEASE_URL=https://github.com/alire-project/GNAT-FSF-builds/releases/download/gnat-16.1.0-1
BME280_COMMIT=3052e7b                 # reznikmm/bme280
BOSCH_COMMIT=c90d419                  # boschsensortec/BME280_SensorAPI

mkdir -p "$WORK_DIRECTORY"
cd "$WORK_DIRECTORY"

download_toolchain () {  # $1 = archive name, $2 = target directory
  if [ ! -d "$2" ]; then
    mkdir -p "$2"
    curl -sL "$RELEASE_URL/$1" | tar xz -C "$2" --strip-components=1
  fi
}

if [ -z "$GNAT_NATIVE_DIRECTORY" ]; then
  GNAT_NATIVE_DIRECTORY=$WORK_DIRECTORY/gnat-native
  download_toolchain gnat-x86_64-linux-16.1.0-1.tar.gz "$GNAT_NATIVE_DIRECTORY"
fi

if [ -z "$GNAT_ARM_DIRECTORY" ]; then
  GNAT_ARM_DIRECTORY=$WORK_DIRECTORY/gnat-arm
  download_toolchain gnat-arm-elf-linux64-x86_64-16.1.0-1.tar.gz "$GNAT_ARM_DIRECTORY"
fi

[ -d bme280 ] || git clone -q https://github.com/reznikmm/bme280
[ -d BME280_SensorAPI ] || git clone -q https://github.com/boschsensortec/BME280_SensorAPI
git -C bme280 checkout -q $BME280_COMMIT
git -C BME280_SensorAPI checkout -q $BOSCH_COMMIT

BME280_SOURCE=$WORK_DIRECTORY/bme280/source
BOSCH_SOURCE=$WORK_DIRECTORY/BME280_SensorAPI

######################################################################
echo "## Accuracy (x86_64)"
######################################################################
mkdir -p native && cd native
export PATH=$GNAT_NATIVE_DIRECTORY/bin:$PATH

for Variant in double:DOUBLE integer_64:64BIT integer_32:32BIT; do
  Name=${Variant%%:*}
  Macro=${Variant##*:}
  gcc -O2 -w -c -I"$BOSCH_SOURCE" -DBME280_${Macro}_ENABLE \
    -DREFERENCE_FUNCTION=reference_$Name \
    "$SCRIPT_DIRECTORY/reference.c" -o reference_$Name.o
  #  Each copy of bme280.c defines the same global names, hide them
  objcopy --keep-global-symbol=reference_$Name reference_$Name.o
done

gnatmake -q -gnat2022 -O2 -gnata -gnato \
  -aI"$BME280_SOURCE" -aI"$BME280_SOURCE/impl" \
  "$SCRIPT_DIRECTORY/compare_accuracy.adb" \
  -largs reference_double.o reference_integer_64.o reference_integer_32.o
./compare_accuracy
cd ..

######################################################################
echo
echo "## Code for Cortex-M4F (STM32F4)"
######################################################################
mkdir -p arm && cd arm
export PATH=$GNAT_ARM_DIRECTORY/bin:$PATH
RUNTIME=$GNAT_ARM_DIRECTORY/arm-eabi/lib/gnat/light-stm32f4
TARGET_FLAGS="-O2 -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16"
C_FLAGS=$TARGET_FLAGS
#  compensate_* are static in bme280.c, keep them out of line to measure
#  (they call no helper functions, so -fno-inline changes nothing else;
#  -fno-ipa-sra -fno-ipa-cp keep their original names and signatures)
C_FLAGS="$C_FLAGS -fno-inline -fno-ipa-sra -fno-ipa-cp"

for Variant in double:DOUBLE integer_64:64BIT integer_32:32BIT; do
  Name=${Variant%%:*}
  Macro=${Variant##*:}
  arm-eabi-gcc $C_FLAGS -w -c -I"$BOSCH_SOURCE" -DBME280_${Macro}_ENABLE \
    "$BOSCH_SOURCE/bme280.c" -o bosch_$Name.o
done

echo 'pragma Restrictions (No_Floating_Point);' > restrictions.adc
#  GNAT wants the object name to match the unit name, so use directories
for Checks in no_checks:-gnatp with_checks:-gnato; do
  mkdir -p ${Checks%%:*}
  (cd ${Checks%%:*} && arm-eabi-gcc -c -gnat2022 $TARGET_FLAGS ${Checks##*:} \
     --RTS="$RUNTIME" -gnatec=../restrictions.adc "$BME280_SOURCE/bme280.adb")
done

echo "| Function | Bytes | Instructions | mul (32-bit result) | mul (64-bit result) | div | FPU | Calls |"
echo "|---|---|---|---|---|---|---|---|"
for Name in double integer_64 integer_32; do
  python3 "$SCRIPT_DIRECTORY/analyze_object.py" arm-eabi-objdump bosch_$Name.o \
    "C $Name: temperature=compensate_temperature" \
    "C $Name: pressure=compensate_pressure" \
    "C $Name: humidity=compensate_humidity"
done
for Checks in no_checks with_checks; do
  python3 "$SCRIPT_DIRECTORY/analyze_object.py" arm-eabi-objdump $Checks/bme280.o \
    "Ada fixed, $Checks: temperature=bme280__temperature" \
    "Ada fixed, $Checks: pressure=bme280__pressure" \
    "Ada fixed, $Checks: humidity=bme280__humidity"
done

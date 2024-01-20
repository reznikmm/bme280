BME280
======

[![Build status](https://github.com/reznikmm/bme280/actions/workflows/alire.yml/badge.svg)](https://github.com/reznikmm/bme280/actions/workflows/alire.yml)
[![Alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/bme280.json)](https://alire.ada.dev/crates/bme280.html)
[![REUSE status](https://api.reuse.software/badge/github.com/reznikmm/bme280)](https://api.reuse.software/info/github.com/reznikmm/bme280)

> Humidity sensor measuring relative humidity, barometric pressure and
> ambient temperature

* [Datasheet](https://www.bosch-sensortec.com/products/environmental-sensors/humidity-sensors-bme280/#documents)

The sensor is available as a module for DIY projects from various
manufacturers, such as [Adafruit](https://www.adafruit.com/product/2652)
and [SparkFun](https://www.sparkfun.com/products/13676). It boasts high
accuracy, a compact size, and the flexibility to connect via both I2C and
SPI interfaces.

The BME280 driver enables the following functionalities:

* Detect the presence of the sensor.
* Perform a reset operation.
* Configure the parameters of the IRR filter and oversampling for each channel.
* Read calibration coefficients.
* Conduct measurements and calibrate the obtained values.
* Calculate the time required for measurements.

## Install

Add `bme280` as a dependency to your crate with Alire:

    alr with bme280

## Usage

The driver implements two usage models: the generic package, which is more
convenient when dealing with a single sensor, and the tagged type, which
allows easy creation of objects for any number of sensors and uniform handling.

Generic instantiation looks like this:

```ada
declare
   package BME280_I2C is new BME280.I2C
     (I2C_Port    => STM32.Device.I2C_1'Access,
      I2C_Address => 16#76#);

begin
   if BME280_I2C.Sensor.Check_Chip_Id then
      BME280_I2C.Sensor.Reset (Ravenscar_Time.Delays, Ok);
      ...
```

While declaring object of the tagged type looks like this:

```ada
declare
   Sensor : BME280.I2C_Sensors.BME280_I2C_Sensor :=
     (I2C_Port    => STM32.Device.I2C_1'Access,
      I2C_Address => 16#76#,
      Calibration => <>);
begin
   if Sensor.Check_Chip_Id then
      Sensor.Reset (Ravenscar_Time.Delays, Ok);
      ...
```

## Examples

You need `Ada_Drivers_Library` in `adl` directory. Clone it then run Alire
to build:

    git clone https://github.com/AdaCore/Ada_Drivers_Library.git adl
    cd examples
    alr build

### GNAT Studio

Launch GNAT Studio with Alire:

    cd examples; alr exec gnatstudio -- -P bme280_put/bme280_put.gpr

### VS Code

Make sure `alr` in the `PATH`.
Open the `examples` folder in VS Code. Use pre-configured tasks to build
projects and flash (openocd or st-util). Install Cortex Debug extension
to launch pre-configured debugger targets.

* [Simple example for STM32 F4VE board](examples/bme280_put) - complete example for the generic instantiation.
* [Advanced example for STM32 F4VE board and LCD & touch panel](examples/bme280_lcd) - complete example of the tagged type usage.

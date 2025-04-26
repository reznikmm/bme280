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
   if BME280_I2C.Check_Chip_Id then
      BME280_I2C.Reset (Ravenscar_Time.Delays, Ok);
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

### Low-Level Interface: `BME280.Raw`

The `BME280.Raw` package provides a low-level interface for interacting with
the BME280 sensor. This package is designed to handle encoding and decoding
of sensor register values, while allowing users to implement the actual
read/write operations in a way that suits their hardware setup. The
communication with the sensor is done by reading or writing one or more bytes
to predefined registers. This package does not depend on HAL and can be used
with DMA or any other method of interacting with the sensor.

#### Purpose of BME280.Raw

The package defines array subtypes where the index represents the register
number, and the value corresponds to the register's data. Functions in this
package help prepare and interpret the register values. For example, functions
prefixed with `Set_` create the values for writing to registers, while those
prefixed with `Get_` decode the values read from registers. Additionally,
functions starting with `Is_` handle boolean logic values, such as checking
if the sensor is measuring or updating.

Users are responsible for implementing the reading and writing of these
register values to the sensor.

#### SPI and I2C Functions

The package also provides helper functions for handling SPI and I2C
communication with the sensor. For write operations, each data byte
must be preceded by a byte containing the register address, since there
is no auto-increment for register addresses in write mode. In contrast,
for read operations, it's enough to specify the register address in
the first byte, after which the sensor will automatically increment
the register address, allowing consecutive data to be read without
needing to specify the address for each byte.

* Two functions convert register address to byte:

  ```ada
  function SPI_Write (X : Register_Address) return Byte;
  function SPI_Read (X : Register_Address) return Byte;
  ```

* Other functions prefix a byte array with the register address:

  ```ada
    function SPI_Write (X : Byte_Array) return Byte_Array;
    function SPI_Read (X : Byte_Array) return Byte_Array
    function I2C_Write (X : Byte_Array) return Byte_Array;
    function I2C_Read (X : Byte_Array) return Byte_Array;
  ```

These functions help abstract the specifics of SPI and I2C communication,
making it easier to focus on the sensor’s register interactions without
worrying about protocol details. For example, you configure the sensor
by specifying the Inactivity duration and the IRR filter:

```ada
declare
   Data : Byte_Array := BME280.Raw.SPI_Write
    (BME280.Raw.Set_Configuration
      (Standby    => 10.0,
       IRR_Filter => X16,
       SPI_3_Wire => False));
begin
   --  Now write Data to the sensor by SPI
```

The reading looks like this:

```ada
declare
   Data : Byte_Array := BME280.Raw.SPI_Read
    ((BME280.Raw.Measurement_Data => 0));
begin
   --  Start SPI exchange (read/write) then decode Data:
   return BME280.Raw.Get_Measurement (Data);
```

## Examples

Examples use `Ada_Drivers_Library`. It's installed by Alire (alr >= 2.1.0 required).
Run Alire to build:

    alr -C examples build

### GNAT Studio

Launch GNAT Studio with Alire:

    alr -C examples exec gnatstudio -- -P bme280_put/bme280_put.gpr

### VS Code

Make sure `alr` in the `PATH`.
Open the `examples` folder in VS Code. Use pre-configured tasks to build
projects and flash (openocd or st-util). Install Cortex Debug extension
to launch pre-configured debugger targets.

* [Simple example for STM32 F4VE board](examples/bme280_put) - complete example for the generic instantiation.
* [Advanced example for STM32 F4VE board and LCD & touch panel](examples/bme280_lcd) - complete example of the tagged type usage.
* [Simple example for SPI1 on STM32 F4VE board](examples/bme280_spi) - SPI example.

### Example of calibration data:

```
(t1 => 28502, t2 => 26652, t3 => 50,
 p1 => 37088, p2 => -10615, p3 => 3024, p4 => 8809, p5 => -130,
 p6 => -7, p7 => 9900, p8 => -10230, p9 => 4285,
 h1 => 75, h2 => 375, h3 => 0, h4 => 289, h5 => 50, h6 => 30)
```
```
(t1 => 28069, t2 => 26689, t3 => 50,
 p1 => 36333, p2 => -10565, p3 => 3024, p4 => 7037, p5 => -18,
 p6 => -7, p7 => 9900, p8 => -10230, p9 => 4285,
 h1 => 75, h2 => 368, h3 => 0, h4 => 305, h5 => 50, h6 => 30)
```
```
(t1 => 28301, t2 => 26667, t3 => 50,
 p1 => 36414, p2 => -10619, p3 => 3024, p4 => 9568, p5 => -163,
 p6 => -7, p7 => 9900, p8 => -10230, p9 => 4285,
 h1 => 75, h2 => 374, h3 => 0, h4 => 290, h5 => 50, h6 => 30)
```

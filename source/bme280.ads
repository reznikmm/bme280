--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Interfaces;

package BME280 is
   pragma Preelaborate;
   pragma Discard_Names;

   type Calibration_Constants is record
      T1 : Interfaces.Unsigned_16;
      T2 : Interfaces.Integer_16;
      T3 : Interfaces.Integer_16;
      P1 : Interfaces.Unsigned_16;
      P2 : Interfaces.Integer_16;
      P3 : Interfaces.Integer_16;
      P4 : Interfaces.Integer_16;
      P5 : Interfaces.Integer_16;
      P6 : Interfaces.Integer_16;
      P7 : Interfaces.Integer_16;
      P8 : Interfaces.Integer_16;
      P9 : Interfaces.Integer_16;
      H1 : Interfaces.Unsigned_8;
      H2 : Interfaces.Integer_16;
      H3 : Interfaces.Unsigned_8;
      H4 : Interfaces.Unsigned_16 range 0 .. 4095;
      H5 : Interfaces.Unsigned_16 range 0 .. 4095;
      H6 : Interfaces.Unsigned_8;
   end record;
   --  Calibration constants per chip. Make visible to allow constant
   --  initialised to a value known in advance.

   type Measurement is private;
   --  Raw values from the sensor

   type Deci_Celsius is delta 1.0 / 2 ** 9 range -99_0.00 .. 99_0.00;
   --  1 degree celsius is 10 Deci_Celsius

   function Temperature
     (Value       : Measurement;
      Calibration : Calibration_Constants) return Deci_Celsius;
   --  Get the temperature from raw values in 0.1 Celsius

   Humidity_Small : constant := 1.0 / 2 ** 10;

   type Relative_Humidity is delta Humidity_Small range 0.0 .. 100.0;
   --  Relative humidity in percent

   function Humidity
     (Value       : Measurement;
      Temperature : Deci_Celsius;
      Calibration : Calibration_Constants) return Relative_Humidity;
   --  Get the humidity from raw values

   Pressure_Small : constant := 1.0 / 2 ** 8;

   type Pressure_Pa is delta Pressure_Small range 30_000.0 .. 110_000.0;
   --  Pressure in Pa

   function Pressure
     (Value       : Measurement;
      Temperature : Deci_Celsius;
      Calibration : Calibration_Constants) return Pressure_Pa;
   --  Get the pressure from raw values

   type Oversampling_Kind is (Skip, X1, X2, X4, X8, X16);
   type IRR_Filter_Kind is (Off, X2, X4, X8, X16);
   type Sensor_Mode is (Sleep, Forced, Normal);
   --  Sensor modes. Sleep - sensor is off, Forced - measure once and go to
   --  sleep, Normal - measure continuously.

   type Standby_Duration is delta 0.5 range 0.5 .. 1000.0
     with Static_Predicate =>
       Standby_Duration in 0.5 | 10.0 | 20.0
         | 62.5 | 125.0 | 250.0 | 500.0 | 1000.0;
   --  Inactivity duration in ms

   function Max_Measurement_Time
     (Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1) return Positive;
   --  Maximal measurement time in microseconds

   function Typical_Measurement_Time
     (Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1) return Positive;
   --  Typical measurement time in microseconds

   Chip_Id : constant := 16#60#;

   subtype Register_Address is Natural range 16#00# .. 16#FF#;
   --  Sensor's register address

   subtype Byte is Interfaces.Unsigned_8;  --  Register value

   type Byte_Array is array (Register_Address range <>) of Byte;
   --  Bytes to be exchanged with registers. Index is a register address, while
   --  elements are corresponding register values.

private

   for Sensor_Mode use (Sleep => 0, Forced => 1, Normal => 3);

   type Unsigned_20 is mod 2**20;

   type Measurement is record
      Raw_Press : Unsigned_20;
      Raw_Temp  : Unsigned_20;
      Raw_Hum   : Interfaces.Integer_16;
   end record;

end BME280;

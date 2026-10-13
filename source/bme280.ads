--  SPDX-FileCopyrightText: 2023-2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
---------------------------------------------------------------------

with Interfaces;

package BME280 is
   pragma Pure;
   pragma Discard_Names;

   --  Calibration coefficients as fixed point values. The register value is
   --  the internal representation of the coefficient, only 'Small is chosen
   --  to make compensation formulas simple. To get a coefficient from the
   --  register value R just write: Register_Type'Small * R

   package Calibration_Register is

      type T1 is delta 2.0**(-10) range 0.0 .. 2.0**6 - 2.0**(-10);

      type T2 is delta 2.0**(-9) range -2.0**6 .. 2.0**6 - 2.0**(-9);

      type T3 is delta 2.0**(-15) range -1.0 .. 1.0 - 2.0**(-15);

      type P1 is delta 1.0 range 0.0 .. 65535.0;

      type P2 is delta 2.0**(-26) range -2.0**(-11) .. 2.0**(-11) - 2.0**(-26);

      type P3 is delta 2.0**(-37) range -2.0**(-22) .. 2.0**(-22) - 2.0**(-37);

      type P4 is delta 2.0**4 range -2.0**19 .. 2.0**19 - 2.0**4;

      type P5 is delta 2.0**(-5) range -2.0**10 .. 2.0**10 - 2.0**(-5);

      type P6 is delta 2.0**(-13) range -4.0 .. 4.0 - 2.0**(-13);

      type P7 is delta 2.0**(-4) range -2.0**11 .. 2.0**11 - 2.0**(-4);

      type P8 is delta 2.0**(-19) range -2.0**(-4) .. 2.0**(-4) - 2.0**(-19);

      type P9 is delta 2.0**(-35) range -2.0**(-20) .. 2.0**(-20) - 2.0**(-35);

      type H1 is delta 2.0**(-19) range 0.0 .. 2.0**(-11) - 2.0**(-19);

      type H2 is delta 2.0**(-16) range -0.5 .. 0.5 - 2.0**(-16);

      type H3 is delta 2.0**(-17) range 0.0 .. 2.0**(-9) - 2.0**(-17);

      type H4 is delta 2.0**6 range -2.0**17 .. 2.0**17 - 2.0**6;

      type H5 is delta 2.0**(-5) range -2.0**6 .. 2.0**6 - 2.0**(-5);

      type H6 is delta 2.0**(-17) range -2.0**(-10) .. 2.0**(-10) - 2.0**(-17);

   end Calibration_Register;

   type Calibration_Constants is record
      T1 : Calibration_Register.T1;  --  register T1 / 2**10
      T2 : Calibration_Register.T2;  --  register T2 / 2**9
      T3 : Calibration_Register.T3;  --  register T3 / 2**15
      P1 : Calibration_Register.P1;  --  register P1
      P2 : Calibration_Register.P2;  --  register P2 / 2**26
      P3 : Calibration_Register.P3;  --  register P3 / 2**37
      P4 : Calibration_Register.P4;  --  register P4 * 2**4
      P5 : Calibration_Register.P5;  --  register P5 / 2**5
      P6 : Calibration_Register.P6;  --  register P6 / 2**13
      P7 : Calibration_Register.P7;  --  register P7 / 2**4
      P8 : Calibration_Register.P8;  --  register P8 / 2**19
      P9 : Calibration_Register.P9;  --  register P9 / 2**35
      H1 : Calibration_Register.H1;  --  register H1 / 2**19
      H2 : Calibration_Register.H2;  --  register H2 / 2**16
      H3 : Calibration_Register.H3;  --  register H3 / 2**17
      H4 : Calibration_Register.H4;  --  register H4 * 2**6
      H5 : Calibration_Register.H5;  --  register H5 / 2**5
      H6 : Calibration_Register.H6;  --  register H6 / 2**17
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

   type Celsius is delta 0.1 digits 3 range -99.00 .. 99.00;
   --  Temperature in degrees Celsius. The accuracy of the device is in the
   --  range of 0.5 .. 1.5.

   function Temperature
     (Value       : Measurement;
      Calibration : Calibration_Constants) return Celsius is
        (0.1 * Deci_Celsius'(Temperature (Value, Calibration)));
   --
   --  Get the temperature from raw values in Celsius

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

   type IIR_Filter_Kind is (Off, X2, X4, X8, X16);

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
      Raw_Press : Natural range 0 .. 2**20 - 1;
      Raw_Temp  : Natural range 0 .. 2**20 - 1;
      Raw_Hum   : Natural range 0 .. 2**16 - 1;
   end record;

end BME280;

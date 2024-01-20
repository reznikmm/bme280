--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package offers a straightforward method for setting up the BME280
--  when connected via I2C, especially useful when the use of only one sensor
--  is required. If you need multiple sensors, it is preferable to use the
--  BME280.I2C_Sensors package, which provides the appropriate tagged type.

with HAL.I2C;
with HAL.Time;

generic
   I2C_Port    : not null HAL.I2C.Any_I2C_Port;
   I2C_Address : HAL.UInt7 := 16#76#;  --  The BME280 7-bit I2C address
package BME280.I2C is

   function Check_Chip_Id (Expect : HAL.UInt8 := 16#60#) return Boolean;
   --  Read the chip ID and check that it matches

   procedure Reset
     (Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean);
   --  Issue a soft reset and wait until the chip is ready.

   procedure Configure
     (Standby    : Standby_Duration := 1000.0;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean);
   --  Configure the sensor to use IRR filtering and/or SPI 3-wire mode

   procedure Start
     (Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean);
   --  Change sensor mode. Mainly used to start one measurement or enable
   --  perpetual cycling of measurements and inactive periods.

   function Measuring return Boolean;
   --  Check if a measurement is in progress

   procedure Read_Measurement
     (Value   : out Measurement;
      Success : out Boolean);
   --  Read the raw measurement values from the sensor

   procedure Read_Calibration
     (Value   : out Calibration_Constants;
      Success : out Boolean);
   --  Read the calibration constants from the sensor

end BME280.I2C;

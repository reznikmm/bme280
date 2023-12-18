--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This generic package contains shared code independent of the sensor
--  connection method. Following the Singleton pattern, it is convenient
--  when using only one sensor is required.

with HAL.Time;

generic
   with procedure Read
     (Data    : out HAL.UInt8_Array;
      Success : out Boolean);
   --  Read the values from the BME280 chip registers into Data.
   --  Each element in the Data corresponds to a specific register address
   --  in the chip, so Data'Range determines the range of registers to read.
   --  The value read from register X will be stored in Data(X), so
   --  Data'Range should be of the Register_Address subtype.

   with procedure Write
     (Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean);
   --  Write the value to the BME280 chip register with given Address.

package BME280.Generic_Sensor is

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

end BME280.Generic_Sensor;

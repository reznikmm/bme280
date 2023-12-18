--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Internal;

package body BME280.Generic_Sensor is

   type Null_Record is null record;

   Chip : constant Null_Record := (null record);

   procedure Read_Sensor
     (Ignore  : Null_Record;
      Data    : out HAL.UInt8_Array;
      Success : out Boolean);

   procedure Write_Sensor
     (Ignore  : Null_Record;
      Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean);

   ------------
   -- Sensor --
   ------------

   package Sensor is new BME280.Internal
     (Null_Record, Read_Sensor, Write_Sensor);

   -------------------
   -- Check_Chip_Id --
   -------------------

   function Check_Chip_Id (Expect : HAL.UInt8 := 16#60#) return Boolean
     is (Sensor.Check_Chip_Id (Chip, Expect));

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Standby    : Standby_Duration := 1000.0;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean) is
   begin
      Sensor.Configure (Chip, Standby, Filter, SPI_3_Wire, Success);
   end Configure;

   ---------------
   -- Measuring --
   ---------------

   function Measuring return Boolean is (Sensor.Measuring (Chip));

   ----------------------
   -- Read_Calibration --
   ----------------------

   procedure Read_Calibration
     (Value   : out Calibration_Constants;
      Success : out Boolean) is
   begin
      Sensor.Read_Calibration (Chip, Value, Success);
   end Read_Calibration;

   ----------------------
   -- Read_Measurement --
   ----------------------

   procedure Read_Measurement
     (Value   : out Measurement;
      Success : out Boolean) is
   begin
      Sensor.Read_Measurement (Chip, Value, Success);
   end Read_Measurement;

   -----------------
   -- Read_Sensor --
   -----------------

   procedure Read_Sensor
     (Ignore  : Null_Record;
      Data    : out HAL.UInt8_Array;
      Success : out Boolean) is
   begin
      Read (Data, Success);
   end Read_Sensor;

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean) is
   begin
      Sensor.Reset (Chip, Timer, Success);
   end Reset;

   -----------
   -- Start --
   -----------

   procedure Start
     (Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean) is
   begin
      Sensor.Start (Chip, Mode, Humidity, Pressure, Temperature, Success);
   end Start;

   ------------------
   -- Write_Sensor --
   ------------------

   procedure Write_Sensor
     (Ignore  : Null_Record;
      Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean) is
   begin
      Write (Address, Data, Success);
   end Write_Sensor;

end BME280.Generic_Sensor;

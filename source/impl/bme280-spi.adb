--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Internal;

package body BME280.SPI is

   type Null_Record is null record;

   Chip : constant Null_Record := (null record);

   procedure Read
     (Ignore  : Null_Record;
      Data    : out Byte_Array;
      Success : out Boolean);

   procedure Write
     (Ignore  : Null_Record;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean);

   ------------
   -- Sensor --
   ------------

   package Sensor is new BME280.Internal (Null_Record, Read, Write);

   -------------------
   -- Check_Chip_Id --
   -------------------

   function Check_Chip_Id (Expect : Byte := Chip_Id) return Boolean
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

   ----------
   -- Read --
   ----------

   procedure Read
     (Ignore  : Null_Record;
      Data    : out Byte_Array;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Addr : HAL.UInt8;
      Status : HAL.SPI.SPI_Status;
      Output : HAL.SPI.SPI_Data_8b (Data'Range);
   begin
      SPI.SPI_CS.Clear;

      Addr := HAL.UInt8 (Data'First) or 16#80#;
      SPI_Port.Transmit (HAL.SPI.SPI_Data_8b'(1 => Addr), Status);

      if Status = Ok then
         SPI_Port.Receive (Output, Status);

         for J in Output'Range loop
            Data (J) := Byte (Output (J));
         end loop;
      end if;

      SPI.SPI_CS.Set;

      Success := Status = Ok;
   end Read;

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

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean)
   is
      procedure Sleep (MS : Positive);

      procedure Sleep (MS : Positive) is
      begin
         Timer.Delay_Milliseconds (MS);
      end Sleep;
   begin
      Sensor.Reset (Chip, Sleep'Access, Success);
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

   -----------
   -- Write --
   -----------

   procedure Write
     (Ignore  : Null_Record;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Prefix : constant HAL.UInt8 := HAL.UInt8 (Address) and 16#7F#;
      Status : HAL.SPI.SPI_Status;
   begin
      SPI.SPI_CS.Clear;

      SPI_Port.Transmit
        (HAL.SPI.SPI_Data_8b'(Prefix, HAL.UInt8 (Data)), Status);

      SPI.SPI_CS.Set;

      Success := Status = Ok;
   end Write;

end BME280.SPI;

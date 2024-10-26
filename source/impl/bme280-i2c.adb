--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Internal;

package body BME280.I2C is

   type Null_Record is null record;

   Chip : constant Null_Record := (null record);

   procedure Read
     (Ignore  : Null_Record;
      Data    : out Byte_Array;
      Success : out Boolean);
   --  Read registers starting from Data'First

   procedure Write
     (Ignore  : Null_Record;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean);
   --  Write the value to the BME280 chip register with given Address.

   package Sensor is new BME280.Internal (Null_Record, Read, Write);

   -------------------
   -- Check_Chip_Id --
   -------------------

   function Check_Chip_Id (Expect : Byte := Chip_Id) return Boolean is
     (Sensor.Check_Chip_Id (Chip, Expect));

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
      use type HAL.I2C.I2C_Status;
      use type HAL.UInt10;

      Status : HAL.I2C.I2C_Status;
      Output : HAL.I2C.I2C_Data (Data'Range);
   begin
      I2C_Port.Mem_Read
        (Addr          => 2 * HAL.UInt10 (I2C_Address),
         Mem_Addr      => HAL.UInt16 (Data'First),
         Mem_Addr_Size => HAL.I2C.Memory_Size_8b,
         Data          => Output,
         Status        => Status);

      for J in Output'Range loop
         Data (J) := Byte (Output (J));
      end loop;

      Success := Status = HAL.I2C.Ok;
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
      Success : out Boolean) is
   begin
      Sensor.Reset (Chip, Success);

      if Success then
         for J in 1 .. 3 loop
            Timer.Delay_Milliseconds (2);
            if not Sensor.Is_Reseting (Chip) then
               return;
            end if;
         end loop;

         Success := False;
      end if;
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
      Data    : Interfaces.Unsigned_8;
      Success : out Boolean)
   is
      use type HAL.I2C.I2C_Status;
      use type HAL.UInt10;

      Status : HAL.I2C.I2C_Status;
   begin
      I2C_Port.Mem_Write
        (Addr          => 2 * HAL.UInt10 (I2C_Address),
         Mem_Addr      => HAL.UInt16 (Address),
         Mem_Addr_Size => HAL.I2C.Memory_Size_8b,
         Data          => (1 => HAL.UInt8 (Data)),
         Status        => Status);

      Success := Status = HAL.I2C.Ok;
   end Write;

end BME280.I2C;

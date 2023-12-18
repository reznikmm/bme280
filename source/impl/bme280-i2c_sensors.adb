--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Internal;

package body BME280.I2C_Sensors is

   procedure Read
     (Self    : BME280_I2C_Sensor'Class;
      Data    : out HAL.UInt8_Array;
      Success : out Boolean);

   procedure Write
     (Self    : BME280_I2C_Sensor'Class;
      Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean);

   package Sensor is
     new BME280.Internal (BME280_I2C_Sensor'Class, Read, Write);

   -------------------
   -- Check_Chip_Id --
   -------------------

   overriding function Check_Chip_Id
     (Self   : BME280_I2C_Sensor;
      Expect : HAL.UInt8 := 16#60#) return Boolean is
       (Sensor.Check_Chip_Id (Self, Expect));

   ---------------
   -- Configure --
   ---------------

   overriding procedure Configure
     (Self       : BME280_I2C_Sensor;
      Standby    : Standby_Duration := 0.5;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean) is
   begin
      Sensor.Configure (Self, Standby, Filter, SPI_3_Wire, Success);
   end Configure;

   overriding function Measuring (Self : BME280_I2C_Sensor) return Boolean is
     (Sensor.Measuring (Self));

   ----------
   -- Read --
   ----------

   procedure Read
     (Self    : BME280_I2C_Sensor'Class;
      Data    : out HAL.UInt8_Array;
      Success : out Boolean)
   is
      use type HAL.I2C.I2C_Status;
      use type HAL.UInt10;

      Status : HAL.I2C.I2C_Status;
   begin
      Self.I2C_Port.Mem_Read
        (Addr          => 2 * HAL.UInt10 (Self.I2C_Address),
         Mem_Addr      => HAL.UInt16 (Data'First),
         Mem_Addr_Size => HAL.I2C.Memory_Size_8b,
         Data          => Data,
         Status        => Status);

      Success := Status = HAL.I2C.Ok;
   end Read;

   ----------------------
   -- Read_Measurement --
   ----------------------

   overriding procedure Read_Measurement
     (Self    : BME280_I2C_Sensor;
      Value   : out Measurement;
      Success : out Boolean) is
   begin
      Sensor.Read_Measurement (Self, Value, Success);
   end Read_Measurement;

   ----------------------
   -- Read_Calibration --
   ----------------------

   overriding procedure Read_Calibration
     (Self    : in out BME280_I2C_Sensor;
      Success : out Boolean) is
   begin
      Sensor.Read_Calibration (Self, Self.Calibration, Success);
   end Read_Calibration;

   -----------
   -- Reset --
   -----------

   overriding procedure Reset
     (Self    : BME280_I2C_Sensor;
      Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean) is
   begin
      Sensor.Reset (Self, Timer, Success);
   end Reset;

   -----------
   -- Start --
   -----------

   overriding procedure Start
     (Self        : BME280_I2C_Sensor;
      Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean) is
   begin
      Sensor.Start (Self, Mode, Humidity, Pressure, Temperature, Success);
   end Start;

   -----------
   -- Write --
   -----------

   procedure Write
     (Self    : BME280_I2C_Sensor'Class;
      Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean)
   is
      use type HAL.I2C.I2C_Status;
      use type HAL.UInt10;

      Status : HAL.I2C.I2C_Status;
   begin
      Self.I2C_Port.Mem_Write
        (Addr          => 2 * HAL.UInt10 (Self.I2C_Address),
         Mem_Addr      => HAL.UInt16 (Address),
         Mem_Addr_Size => HAL.I2C.Memory_Size_8b,
         Data          => (1 => Data),
         Status        => Status);

      Success := Status = HAL.I2C.Ok;
   end Write;

end BME280.I2C_Sensors;

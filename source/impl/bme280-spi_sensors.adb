--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Internal;

package body BME280.SPI_Sensors is

   procedure Read
     (Self    : BME280_SPI_Sensor'Class;
      Data    : out Byte_Array;
      Success : out Boolean);

   procedure Write
     (Self    : BME280_SPI_Sensor'Class;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean);

   package Sensor is
     new BME280.Internal (BME280_SPI_Sensor'Class, Read, Write);

   -------------------
   -- Check_Chip_Id --
   -------------------

   overriding function Check_Chip_Id
     (Self   : BME280_SPI_Sensor;
      Expect : Byte := Chip_Id) return Boolean is
       (Sensor.Check_Chip_Id (Self, Expect));

   ---------------
   -- Configure --
   ---------------

   overriding procedure Configure
     (Self       : BME280_SPI_Sensor;
      Standby    : Standby_Duration := 0.5;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean) is
   begin
      Sensor.Configure (Self, Standby, Filter, SPI_3_Wire, Success);
   end Configure;

   overriding function Measuring (Self : BME280_SPI_Sensor) return Boolean is
     (Sensor.Measuring (Self));

   ----------
   -- Read --
   ----------

   procedure Read
     (Self    : BME280_SPI_Sensor'Class;
      Data    : out Byte_Array;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Addr : HAL.UInt8;
      Status : HAL.SPI.SPI_Status;
      Output : HAL.SPI.SPI_Data_8b (Data'Range);
   begin
      Self.SPI_CS.Clear;

      Addr := HAL.UInt8 (Data'First) or 16#80#;
      Self.SPI_Port.Transmit (HAL.SPI.SPI_Data_8b'(1 => Addr), Status);

      if Status = Ok then
         Self.SPI_Port.Receive (Output, Status);

         for J in Output'Range loop
            Data (J) := Byte (Output (J));
         end loop;
      end if;

      Self.SPI_CS.Set;

      Success := Status = Ok;
   end Read;

   ----------------------
   -- Read_Measurement --
   ----------------------

   overriding procedure Read_Measurement
     (Self    : BME280_SPI_Sensor;
      Value   : out Measurement;
      Success : out Boolean) is
   begin
      Sensor.Read_Measurement (Self, Value, Success);
   end Read_Measurement;

   ----------------------
   -- Read_Calibration --
   ----------------------

   overriding procedure Read_Calibration
     (Self    : in out BME280_SPI_Sensor;
      Success : out Boolean) is
   begin
      Sensor.Read_Calibration (Self, Self.Calibration, Success);
   end Read_Calibration;

   -----------
   -- Reset --
   -----------

   overriding procedure Reset
     (Self    : BME280_SPI_Sensor;
      Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean) is
   begin
      Sensor.Reset (Self, Success);

      if Success then
         for J in 1 .. 3 loop
            Timer.Delay_Milliseconds (2);
            if not Sensor.Is_Reseting (Self) then
               return;
            end if;
         end loop;

         Success := False;
      end if;
   end Reset;

   -----------
   -- Start --
   -----------

   overriding procedure Start
     (Self        : BME280_SPI_Sensor;
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
     (Self    : BME280_SPI_Sensor'Class;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Prefix : constant HAL.UInt8 := HAL.UInt8 (Address) and 16#7F#;
      Status : HAL.SPI.SPI_Status;
   begin
      Self.SPI_CS.Clear;

      Self.SPI_Port.Transmit
        (HAL.SPI.SPI_Data_8b'(Prefix, HAL.UInt8 (Data)), Status);

      Self.SPI_CS.Set;

      Success := Status = Ok;
   end Write;

end BME280.SPI_Sensors;

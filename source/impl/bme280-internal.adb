--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with BME280.Raw;

package body BME280.Internal is

   -------------------
   -- Check_Chip_Id --
   -------------------

   function Check_Chip_Id
     (Device : Device_Context;
      Expect : Byte) return Boolean
   is
      use type Byte;
      Ok   : Boolean;
      Data : Raw.Chip_Id_Data;
   begin
      Read (Device, Data, Ok);

      return Ok and Raw.Get_Chip_Id (Data) = Expect;
   end Check_Chip_Id;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Device     : Device_Context;
      Standby    : Standby_Duration;
      Filter     : IRR_Filter_Kind;
      SPI_3_Wire : Boolean;
      Success    : out Boolean)
   is
      Data : constant Raw.Configuration_Data :=
        Raw.Set_Configuration (Standby, Filter, SPI_3_Wire);
   begin
      Write (Device, Data'First, Data (Data'First), Success);
   end Configure;

   ---------------
   -- Measuring --
   ---------------

   function Measuring (Device : Device_Context) return Boolean is
      Ok   : Boolean;
      Data : Raw.Status_Data;
   begin
      Read (Device, Data, Ok);

      return Ok and Raw.Is_Measuring (Data);
   end Measuring;

   ----------------------
   -- Read_Calibration --
   ----------------------

   procedure Read_Calibration
     (Device  : Device_Context;
      Value   : out Calibration_Constants;
      Success : out Boolean)
   is
      CC : Raw.Calibration_Constants_Data;
   begin
      Read (Device, CC.Data_1, Success);

      if Success then
         Read (Device, CC.Data_2, Success);
      end if;

      if Success then
         Value := Raw.Get_Calibration_Constants (CC);
      end if;
   end Read_Calibration;

   ----------------------
   -- Read_Measurement --
   ----------------------

   procedure Read_Measurement
     (Device  : Device_Context;
      Value   : out Measurement;
      Success : out Boolean)
   is
      Data : Raw.Measurement_Data;
   begin
      Read (Device, Data, Success);

      if Success then
         Value := Raw.Get_Measurement (Data);
      end if;
   end Read_Measurement;

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Device  : Device_Context;
      Timer   : not null access procedure (Millisecond : Positive);
      Success : out Boolean)
   is
      Reset : Byte_Array renames Raw.Set_Reset;
      Data : Raw.Status_Data;
   begin
      Write (Device, Reset'First, Reset (Reset'First), Success);

      if not Success then
         return;
      end if;

      for J in 1 .. 3 loop
         Timer (2);
         Read (Device, Data, Success);

         if Success and then not Raw.Is_Reseting (Data) then
            return;
         end if;
      end loop;

      Success := False;
   end Reset;

   -----------
   -- Start --
   -----------

   procedure Start
     (Device      : Device_Context;
      Mode        : Sensor_Mode;
      Humidity    : Oversampling_Kind;
      Pressure    : Oversampling_Kind;
      Temperature : Oversampling_Kind;
      Success     : out Boolean)
   is
      Data : constant Raw.Mode_Data := Raw.Set_Mode
        (Mode, Humidity, Pressure, Temperature);
   begin
      Write (Device, Data'First, Data (Data'First), Success);

      if Success then
         Write (Device, Data'Last, Data (Data'Last), Success);
      end if;
   end Start;


end BME280.Internal;

--  SPDX-FileCopyrightText: 2024-2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
---------------------------------------------------------------------

with Ada.Unchecked_Conversion;

package body BME280.Raw is

   -------------------------------
   -- Get_Calibration_Constants --
   -------------------------------

   function Get_Calibration_Constants
     (Raw : Calibration_Constants_Data) return Calibration_Constants
   is
      use Interfaces;

      function Cast is new Ada.Unchecked_Conversion
        (Unsigned_16, Integer_16);

      function Cast is new Ada.Unchecked_Conversion (Unsigned_8, Integer_8);

      function Word (LSB, MSB : Byte) return Natural is
        (Natural (LSB) + 256 * Natural (MSB));

      function Signed (LSB, MSB : Byte) return Integer is
        (Integer (Cast (Unsigned_16 (Word (LSB, MSB)))));

      function Signed (Value : Byte) return Integer is
        (Integer (Cast (Value)));

      Value : Calibration_Constants;
   begin
      declare
         use Calibration_Register;
         Data : Byte_Array renames Raw.Data_1;
      begin
         Value.T1 := T1'Small * Word (Data (16#88#), Data (16#89#));
         Value.T2 := T2'Small * Signed (Data (16#8A#), Data (16#8B#));
         Value.T3 := T3'Small * Signed (Data (16#8C#), Data (16#8D#));

         Value.P1 := P1'Small * Word (Data (16#8E#), Data (16#8F#));
         Value.P2 := P2'Small * Signed (Data (16#90#), Data (16#91#));
         Value.P3 := P3'Small * Signed (Data (16#92#), Data (16#93#));
         Value.P4 := P4'Small * Signed (Data (16#94#), Data (16#95#));
         Value.P5 := P5'Small * Signed (Data (16#96#), Data (16#97#));
         Value.P6 := P6'Small * Signed (Data (16#98#), Data (16#99#));
         Value.P7 := P7'Small * Signed (Data (16#9A#), Data (16#9B#));
         Value.P8 := P8'Small * Signed (Data (16#9C#), Data (16#9D#));
         Value.P9 := P9'Small * Signed (Data (16#9E#), Data (16#9F#));

         Value.H1 := H1'Small * Natural (Data (16#A1#));
      end;

      declare
         use Calibration_Register;
         Data : Byte_Array renames Raw.Data_2;
      begin
         Value.H2 := H2'Small * Signed (Data (16#E1#), Data (16#E2#));
         Value.H3 := H3'Small * Natural (Data (16#E3#));

         Value.H4 := H4'Small *
           (Signed (Data (16#E4#)) * 16 + Natural (Data (16#E5#) and 16#0F#));

         Value.H5 := H5'Small *
           (Signed (Data (16#E6#)) * 16 + Natural (Data (16#E5#) / 16));

         Value.H6 := H6'Small * Signed (Data (16#E7#));
      end;

      return Value;
   end Get_Calibration_Constants;

   ---------------------
   -- Get_Measurement --
   ---------------------

   function Get_Measurement (Raw : Byte_Array) return Measurement is
      use Interfaces;

      Value : Measurement;
   begin
      Value.Raw_Press := Natural
        (Shift_Left    (Unsigned_32 (Raw (16#F7#)), 12)
         + Shift_Left  (Unsigned_32 (Raw (16#F8#)), 4)
         + Shift_Right (Unsigned_32 (Raw (16#F9#)), 4));

      Value.Raw_Temp := Natural
        (Shift_Left    (Unsigned_32 (Raw (16#FA#)), 12)
         + Shift_Left  (Unsigned_32 (Raw (16#FB#)), 4)
         + Shift_Right (Unsigned_32 (Raw (16#FC#)), 4));

      Value.Raw_Hum := Natural
        (Shift_Left (Unsigned_16 (Raw (16#FD#)), 8)
         + Unsigned_16 (Raw (16#FE#)));

      return Value;
   end Get_Measurement;

   -----------------------
   -- Set_Configuration --
   -----------------------

   function Set_Configuration
     (Standby    : Standby_Duration;
      Filter     : IRR_Filter_Kind;
      SPI_3_Wire : Boolean) return Configuration_Data
   is
      Data : Byte;
   begin
      if Standby = 0.5 then
         Data := 0;
      elsif Standby = 20.0 then
         Data := 7;
      elsif Standby = 10.0 then
         Data := 6;
      else
         Data := 5;
         declare
            Value : Standby_Duration := 1000.0;
         begin
            while Value > Standby loop
               Value := Value / 2;
               Data := Data - 1;
            end loop;
         end;
      end if;

      Data := Data * 8 + IRR_Filter_Kind'Pos (Filter);
      Data := Data * 4 + Boolean'Pos (SPI_3_Wire);

      return (Configuration_Data'First => Data);
   end Set_Configuration;

   --------------
   -- Set_Mode --
   --------------

   function Set_Mode
     (Mode        : Sensor_Mode;
      Humidity    : Oversampling_Kind;
      Pressure    : Oversampling_Kind;
      Temperature : Oversampling_Kind) return Mode_Data
   is
      Data  : Byte;
      Value : Mode_Data;
   begin
      Value (16#F2#) := Oversampling_Kind'Pos (Humidity);
      Value (16#F3#) := 0;

      Data := Oversampling_Kind'Pos (Temperature);
      Data := Data * 8 + Oversampling_Kind'Pos (Pressure);
      Data := Data * 4 + Sensor_Mode'Enum_Rep (Mode);
      Value (16#F4#) := Data;

      return Value;
   end Set_Mode;

end BME280.Raw;

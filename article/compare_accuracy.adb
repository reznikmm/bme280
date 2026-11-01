--  Compare BME280 compensation formulas:
--  * Bosch double version (used as the reference),
--  * Bosch 64-bit integer version,
--  * Bosch 32-bit integer version,
--  * Ada fixed point version from reznikmm/bme280.
--
--  For each calibration set from the README the program sweeps a grid of
--  raw ADC values and reports the maximum and RMS deviation from the
--  double version. Only "physical" points are counted: those where the
--  double version is not clamped (-40..85 C, 300..1100 hPa, 0..100 %).

with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Interfaces;

with BME280.Raw;

procedure Compare_Accuracy is
   use BME280;
   use Interfaces;

   type Result_Array is array (1 .. 3) of Long_Float with Convention => C;
   --  Temperature (Celsius), Pressure (Pa), Humidity (%)

   procedure Reference_Double
     (Calibration_Registers_88_A1 : Byte_Array;
      Calibration_Registers_E1_E7 : Byte_Array;
      Raw_Pressure                : Unsigned_32;
      Raw_Temperature             : Unsigned_32;
      Raw_Humidity                : Unsigned_32;
      Result                      : out Result_Array;
      Temperature_Fine            : out Integer_32)
     with Import, Convention => C, External_Name => "reference_double";

   procedure Reference_Integer_64
     (Calibration_Registers_88_A1 : Byte_Array;
      Calibration_Registers_E1_E7 : Byte_Array;
      Raw_Pressure                : Unsigned_32;
      Raw_Temperature             : Unsigned_32;
      Raw_Humidity                : Unsigned_32;
      Result                      : out Result_Array;
      Temperature_Fine            : out Integer_32)
     with Import, Convention => C, External_Name => "reference_integer_64";

   procedure Reference_Integer_32
     (Calibration_Registers_88_A1 : Byte_Array;
      Calibration_Registers_E1_E7 : Byte_Array;
      Raw_Pressure                : Unsigned_32;
      Raw_Temperature             : Unsigned_32;
      Raw_Humidity                : Unsigned_32;
      Result                      : out Result_Array;
      Temperature_Fine            : out Integer_32)
     with Import, Convention => C, External_Name => "reference_integer_32";

   type Calibration_Set is record
      T1, T2, T3                             : Integer;
      P1, P2, P3, P4, P5, P6, P7, P8, P9     : Integer;
      H1, H2, H3, H4, H5, H6                 : Integer;
   end record;

   --  Calibration data of three real sensors (see README.md)
   Calibration_Sets : constant array (1 .. 3) of Calibration_Set :=
     [(T1 => 28502, T2 => 26652, T3 => 50,
       P1 => 37088, P2 => -10615, P3 => 3024, P4 => 8809, P5 => -130,
       P6 => -7, P7 => 9900, P8 => -10230, P9 => 4285,
       H1 => 75, H2 => 375, H3 => 0, H4 => 289, H5 => 50, H6 => 30),
      (T1 => 28069, T2 => 26689, T3 => 50,
       P1 => 36333, P2 => -10565, P3 => 3024, P4 => 7037, P5 => -18,
       P6 => -7, P7 => 9900, P8 => -10230, P9 => 4285,
       H1 => 75, H2 => 368, H3 => 0, H4 => 305, H5 => 50, H6 => 30),
      (T1 => 28301, T2 => 26667, T3 => 50,
       P1 => 36414, P2 => -10619, P3 => 3024, P4 => 9568, P5 => -163,
       P6 => -7, P7 => 9900, P8 => -10230, P9 => 4285,
       H1 => 75, H2 => 374, H3 => 0, H4 => 290, H5 => 50, H6 => 30)];

   type Implementation is (Integer_64_Version, Integer_32_Version, Fixed_Point_Version);

   type Statistics is record
      Maximum      : Result_Array := [others => 0.0];
      Sum_Of_Squares : Result_Array := [others => 0.0];
   end record;

   Total : array (Implementation) of Statistics;
   Point_Count : Natural := 0;

   procedure Put_Word
     (Data     : in out Byte_Array;
      Address  : Register_Address;
      Value    : Integer)
   is
      Word : constant Unsigned_16 := Unsigned_16 (Value mod 2**16);
   begin
      Data (Address) := Byte (Word and 16#FF#);
      Data (Address + 1) := Byte (Shift_Right (Word, 8));
   end Put_Word;

   procedure Encode
     (Set : Calibration_Set;
      Raw : out BME280.Raw.Calibration_Constants_Data)
   is
      H4 : constant Integer := Set.H4 mod 2**12;
      H5 : constant Integer := Set.H5 mod 2**12;
   begin
      Raw.Data_1 := [others => 0];
      Raw.Data_2 := [others => 0];
      Put_Word (Raw.Data_1, 16#88#, Set.T1);
      Put_Word (Raw.Data_1, 16#8A#, Set.T2);
      Put_Word (Raw.Data_1, 16#8C#, Set.T3);
      Put_Word (Raw.Data_1, 16#8E#, Set.P1);
      Put_Word (Raw.Data_1, 16#90#, Set.P2);
      Put_Word (Raw.Data_1, 16#92#, Set.P3);
      Put_Word (Raw.Data_1, 16#94#, Set.P4);
      Put_Word (Raw.Data_1, 16#96#, Set.P5);
      Put_Word (Raw.Data_1, 16#98#, Set.P6);
      Put_Word (Raw.Data_1, 16#9A#, Set.P7);
      Put_Word (Raw.Data_1, 16#9C#, Set.P8);
      Put_Word (Raw.Data_1, 16#9E#, Set.P9);
      Raw.Data_1 (16#A1#) := Byte (Set.H1);
      Put_Word (Raw.Data_2, 16#E1#, Set.H2);
      Raw.Data_2 (16#E3#) := Byte (Set.H3);
      Raw.Data_2 (16#E4#) := Byte (H4 / 16);
      Raw.Data_2 (16#E5#) := Byte (H4 mod 16 + (H5 mod 16) * 16);
      Raw.Data_2 (16#E6#) := Byte (H5 / 16);
      Raw.Data_2 (16#E7#) := Byte (Set.H6 mod 256);
   end Encode;

   procedure Encode
     (Raw_Pressure    : Unsigned_32;
      Raw_Temperature : Unsigned_32;
      Raw_Humidity    : Unsigned_32;
      Data            : out BME280.Raw.Measurement_Data) is
   begin
      Data :=
        [16#F7# => Byte (Shift_Right (Raw_Pressure, 12) and 16#FF#),
         16#F8# => Byte (Shift_Right (Raw_Pressure, 4) and 16#FF#),
         16#F9# => Byte ((Raw_Pressure and 16#0F#) * 16),
         16#FA# => Byte (Shift_Right (Raw_Temperature, 12) and 16#FF#),
         16#FB# => Byte (Shift_Right (Raw_Temperature, 4) and 16#FF#),
         16#FC# => Byte ((Raw_Temperature and 16#0F#) * 16),
         16#FD# => Byte (Shift_Right (Raw_Humidity, 8)),
         16#FE# => Byte (Raw_Humidity and 16#FF#)];
   end Encode;

   procedure Account
     (Version   : Implementation;
      Value     : Result_Array;
      Reference : Result_Array) is
   begin
      for Index in Value'Range loop
         declare
            Error : constant Long_Float := abs (Value (Index) - Reference (Index));
         begin
            Total (Version).Maximum (Index) :=
              Long_Float'Max (Total (Version).Maximum (Index), Error);
            Total (Version).Sum_Of_Squares (Index) :=
              Total (Version).Sum_Of_Squares (Index) + Error ** 2;
         end;
      end loop;
   end Account;

   function Image (Value : Long_Float) return String is
      package Long_Float_IO is new Ada.Text_IO.Float_IO (Long_Float);
      Text : String (1 .. 12);
   begin
      Long_Float_IO.Put (Text, Value, Aft => 1, Exp => 3);
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Left);
   end Image;

begin
   for Set of Calibration_Sets loop
      declare
         Raw_Calibration : BME280.Raw.Calibration_Constants_Data;
      begin
         Encode (Set, Raw_Calibration);

         declare
            Calibration : constant Calibration_Constants :=
              BME280.Raw.Get_Calibration_Constants (Raw_Calibration);
         begin
            for Temperature_Step in 0 .. 80 loop
               for Pressure_Step in 0 .. 130 loop
                  for Humidity_Step in 0 .. 60 loop
                     declare
                        Raw_Temperature : constant Unsigned_32 :=
                          300_000 + Unsigned_32 (Temperature_Step) * 5_000;
                        Raw_Pressure : constant Unsigned_32 :=
                          150_000 + Unsigned_32 (Pressure_Step) * 5_000;
                        Raw_Humidity : constant Unsigned_32 :=
                          5_000 + Unsigned_32 (Humidity_Step) * 1_000;

                        Double_Result      : Result_Array;
                        Integer_64_Result  : Result_Array;
                        Integer_32_Result  : Result_Array;
                        Fixed_Point_Result : Result_Array;
                        Temperature_Fine   : Integer_32;
                     begin
                        Reference_Double
                          (Raw_Calibration.Data_1, Raw_Calibration.Data_2,
                           Raw_Pressure, Raw_Temperature, Raw_Humidity,
                           Double_Result, Temperature_Fine);

                        if Double_Result (1) > -40.0
                          and Double_Result (1) < 85.0
                          and Double_Result (2) > 30_000.0
                          and Double_Result (2) < 110_000.0
                          and Double_Result (3) > 0.0
                          and Double_Result (3) < 100.0
                        then
                           Point_Count := Point_Count + 1;

                           Reference_Integer_64
                             (Raw_Calibration.Data_1, Raw_Calibration.Data_2,
                              Raw_Pressure, Raw_Temperature, Raw_Humidity,
                              Integer_64_Result, Temperature_Fine);

                           Reference_Integer_32
                             (Raw_Calibration.Data_1, Raw_Calibration.Data_2,
                              Raw_Pressure, Raw_Temperature, Raw_Humidity,
                              Integer_32_Result, Temperature_Fine);

                           declare
                              Measurement_Data : BME280.Raw.Measurement_Data;
                           begin
                              Encode
                                (Raw_Pressure, Raw_Temperature, Raw_Humidity,
                                 Measurement_Data);

                              declare
                                 Value : constant Measurement :=
                                   BME280.Raw.Get_Measurement (Measurement_Data);
                                 Temperature_Value : constant Deci_Celsius :=
                                   Temperature (Value, Calibration);
                              begin
                                 Fixed_Point_Result :=
                                   [Long_Float (Temperature_Value) / 10.0,
                                    Long_Float
                                      (Pressure (Value, Temperature_Value, Calibration)),
                                    Long_Float
                                      (Humidity (Value, Temperature_Value, Calibration))];
                              end;
                           end;

                           Account (Integer_64_Version, Integer_64_Result, Double_Result);
                           Account (Integer_32_Version, Integer_32_Result, Double_Result);
                           Account (Fixed_Point_Version, Fixed_Point_Result, Double_Result);
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;
         end;
      end;
   end loop;

   Ada.Text_IO.Put_Line
     ("Points compared:" & Point_Count'Image
      & " (3 calibration sets, values in physical range)");
   Ada.Text_IO.New_Line;
   Ada.Text_IO.Put_Line
     ("| Version | Temperature, C (max / RMS) | Pressure, Pa (max / RMS) "
      & "| Humidity, % (max / RMS) |");
   Ada.Text_IO.Put_Line ("|---|---|---|---|");

   for Version in Implementation loop
      declare
         use Ada.Numerics.Long_Elementary_Functions;

         Name : constant array (Implementation) of access constant String :=
           [Integer_64_Version  => new String'("Bosch, 64-bit integer"),
            Integer_32_Version  => new String'("Bosch, 32-bit integer"),
            Fixed_Point_Version => new String'("Ada, fixed point")];

         Line : String renames Name (Version).all;

         function Cell (Index : Positive) return String is
           (Image (Total (Version).Maximum (Index)) & " / "
            & Image (Sqrt (Total (Version).Sum_Of_Squares (Index)
                           / Long_Float (Point_Count))));
      begin
         Ada.Text_IO.Put_Line
           ("| " & Line & " | " & Cell (1) & " | " & Cell (2) & " | "
            & Cell (3) & " |");
      end;
   end loop;
end Compare_Accuracy;

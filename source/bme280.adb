--  SPDX-FileCopyrightText: 2023-2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
---------------------------------------------------------------------

package body BME280 is

   function Slowdown (Kind : Oversampling_Kind) return Natural is
     (case Kind is
         when Skip => 0,
         when X1 => 1,
         when X2 => 2,
         when X4 => 4,
         when X8 => 8,
         when X16 => 16);
   --  Map Oversamping_Kind to the integer slowdown coefficient

   --------------
   -- Humidity --
   --------------

   function Humidity
     (Value       : Measurement;
      Temperature : Deci_Celsius;
      Calibration : Calibration_Constants) return Relative_Humidity
   is
      --  T = Temperature - 15.0 C (in deci-celsius)
      --  B = 1 + T * H3,
      --  F = B * (1 + T * H6 * B)
      --  X = (ADC - H4 - T * H5) * H2 * F,
      --  RH = X * (1 - X * H1)
      type Offset is delta 2.0**(-11) range -2.0**19 .. 2.0**19;
      type Factor is delta 2.0**(-24) range -2.0**6 .. 2.0**6;
      type Wide is delta 2.0**(-10) range -2.0**20 .. 2.0**20;

      Max : constant Wide := Wide (Relative_Humidity'Last);

      C : Calibration_Constants renames Calibration;

      T : constant Offset := Offset (Temperature) - 150.0;  --  from 15.0 C
      B : constant Factor := 1.0 + T * C.H3;
      F : constant Factor := B * Factor'(1.0 + Factor (T * C.H6) * B);
      H : constant Offset := 1.0 * Value.Raw_Hum - 1.0 * C.H4 - T * C.H5;
      X : constant Wide := Wide (H * C.H2) * F;

      Result : constant Wide := X * Factor'(1.0 - X * C.H1);

   begin
      return Relative_Humidity (Wide'Max (0.0, Wide'Min (Result, Max)));
   end Humidity;

   --------------------------
   -- Max_Measurement_Time --
   --------------------------

   function Max_Measurement_Time
     (Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1) return Positive is
        (1_250
         + (if Temperature = Skip then 0 else 2_300 * Slowdown (Temperature))
         + (if Pressure = Skip then 0 else 2_300 * Slowdown (Pressure) + 575)
         + (if Humidity = Skip then 0 else 2_300 * Slowdown (Humidity) + 575));

   --------------
   -- Pressure --
   --------------

   function Pressure
     (Value       : Measurement;
      Temperature : Deci_Celsius;
      Calibration : Calibration_Constants) return Pressure_Pa
   is
      --  T = Temperature - 25.0 C (in deci-celsius)
      --  P = (2**20 - ADC - (P4 + T * (P5 + T * P6)))
      --        * 6250 / (P1 * (1 + T * (P2 + T * P3)))
      --  Pa = P7 + P * (1 + P8 + P * P9)
      type Offset is delta 2.0**(-9) range -2.0**12 .. 2.0**12;
      type Slope is delta 2.0**(-38) range -2.0**(-8) .. 2.0**(-8);
      type Factor is delta 2.0**(-26) range -2.0**4 .. 2.0**4;
      type Linear is delta 2.0**(-14) range -2.0**16 .. 2.0**16;
      type Ratio is delta 2.0**(-24) range -2.0**6 .. 2.0**6;
      type Denominator is delta 2.0**(-13) range -2.0**17 .. 2.0**17;
      type Wide is delta 2.0**(-8) range -2.0**22 .. 2.0**22;

      Min : constant Wide := Wide (Pressure_Pa'First);
      Max : constant Wide := Wide (Pressure_Pa'Last);

      C : Calibration_Constants renames Calibration;

      P2 : constant Slope := Slope (C.P2);
      P4 : constant Wide := Wide (C.P4);
      P5 : constant Linear := Linear (C.P5);
      P7 : constant Wide := Wide (C.P7);
      P8 : constant Factor := Factor (C.P8);

      T  : constant Offset := Offset (Temperature) - 250.0;  --  from 25.0 C
      K  : constant Factor := 1.0 + T * Slope'(P2 + T * C.P3);
      D  : constant Wide := P4 + T * Linear'(P5 + T * C.P6);
      N  : constant Wide := Wide (2**20 - Value.Raw_Press) - D;
      Q  : constant Denominator := C.P1 * K;

      Result : Wide;

   begin
      if Q <= 0.0 then
         return Pressure_Pa'First;
      else
         Result := Ratio'(N / Q) * 6250.0;
         Result := P7 + Result * Factor'(1.0 + P8 + Result * C.P9);

         return Pressure_Pa (Wide'Max (Min, Wide'Min (Result, Max)));
      end if;
   end Pressure;

   -----------------
   -- Temperature --
   -----------------

   function Temperature
     (Value       : Measurement;
      Calibration : Calibration_Constants) return Deci_Celsius
   is
      --  X = ADC / 2**14 - T1
      --  T = X * (T2 + X * T3)   (in deci-celsius)
      type ADC is delta 2.0**(-14) range -2.0**7 .. 2.0**7;
      type Slope is delta 2.0**(-20) range -2.0**8 .. 2.0**8;
      type Wide is delta 2.0**(-9) range -2.0**16 .. 2.0**16;

      C : Calibration_Constants renames Calibration;

      T1 : constant ADC := ADC (C.T1);
      T2 : constant Slope := Slope (C.T2);

      Diff   : constant ADC := ADC'Small * Value.Raw_Temp - T1;
      Result : constant Wide := Diff * (T2 + Diff * C.T3);

      Min : constant Wide := Wide (Deci_Celsius'First);
      Max : constant Wide := Wide (Deci_Celsius'Last);

   begin
      return Deci_Celsius (Wide'Max (Min, Wide'Min (Result, Max)));
   end Temperature;

   ------------------------------
   -- Typical_Measurement_Time --
   ------------------------------

   function Typical_Measurement_Time
     (Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1) return Positive is
        (1_000
         + (if Temperature = Skip then 0 else 2_000 * Slowdown (Temperature))
         + (if Pressure = Skip then 0 else 2_000 * Slowdown (Pressure) + 500)
         + (if Humidity = Skip then 0 else 2_000 * Slowdown (Humidity) + 500));

end BME280;

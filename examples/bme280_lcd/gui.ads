--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

pragma Ada_2022;

with GUI_Buttons;
with HAL.Bitmap;
with HAL.Touch_Panel;

package GUI is

   type Button_Kind is
     (
      Te,
      Te_X1,
      Te_X2,
      Te_X4,
      Te_X8,
      Te_16,
      Hu,
      Hu_X1,
      Hu_X2,
      Hu_X4,
      Hu_X8,
      Hu_16,
      Pr,
      Pr_X1,
      Pr_X2,
      Pr_X4,
      Pr_X8,
      Pr_16,
      Fi,
      Fi_No,
      Fi_X2,
      Fi_X4,
      Fi_X8,
      Fi_16);

   function "+" (X : Button_Kind) return Natural is (Button_Kind'Pos (X))
     with Static;

   Buttons : constant GUI_Buttons.Button_Info_Array :=
     [
      (Label  => "Te",
       Center => (23 * 1, 20),
       Color  => HAL.Bitmap.Dark_Red),
      (Label  => "x1",
       Center => (23 * 2, 20),
       Color  => HAL.Bitmap.Dark_Red),
      (Label  => "x2",
       Center => (23 * 3, 20),
       Color  => HAL.Bitmap.Dark_Red),
      (Label  => "x4",
       Center => (23 * 4, 20),
       Color  => HAL.Bitmap.Dark_Red),
      (Label  => "x8",
       Center => (23 * 5, 20),
       Color  => HAL.Bitmap.Dark_Red),
      (Label  => "16",
       Center => (23 * 6, 20),
       Color  => HAL.Bitmap.Dark_Red),

      (Label  => "Hu",
       Center => (23 * 1 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),
      (Label  => "x1",
       Center => (23 * 2 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),
      (Label  => "x2",
       Center => (23 * 3 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),
      (Label  => "x4",
       Center => (23 * 4 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),
      (Label  => "x8",
       Center => (23 * 5 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),
      (Label  => "16",
       Center => (23 * 6 + 160, 20),
       Color  => HAL.Bitmap.Dark_Green),

      (Label  => "Pr",
       Center => (23 * 1, 220),
       Color  => HAL.Bitmap.Dark_Blue),
      (Label  => "x1",
       Center => (23 * 2, 220),
       Color  => HAL.Bitmap.Dark_Blue),
      (Label  => "x2",
       Center => (23 * 3, 220),
       Color  => HAL.Bitmap.Dark_Blue),
      (Label  => "x4",
       Center => (23 * 4, 220),
       Color  => HAL.Bitmap.Dark_Blue),
      (Label  => "x8",
       Center => (23 * 5, 220),
       Color  => HAL.Bitmap.Dark_Blue),
      (Label  => "16",
       Center => (23 * 6, 220),
       Color  => HAL.Bitmap.Dark_Blue),

      (Label  => "Fi",
       Center => (23 * 1 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey),
      (Label  => "No",
       Center => (23 * 2 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey),
      (Label  => "x2",
       Center => (23 * 3 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey),
      (Label  => "x4",
       Center => (23 * 4 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey),
      (Label  => "x8",
       Center => (23 * 5 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey),
      (Label  => "16",
       Center => (23 * 6 + 160, 220),
       Color  => HAL.Bitmap.Dim_Grey)];

   State : GUI_Buttons.Boolean_Array (Buttons'Range) :=
     [+Hu    | +Te    | +Pr |
      +Hu_X1 | +Te_X1 | +Pr_X1 |
      +Fi_No => True,
      others => False];

   procedure Check_Touch
     (TP     : in out HAL.Touch_Panel.Touch_Panel_Device'Class;
      Update : out Boolean);
   --  Check buttons touchedm update State, set Update = True if State changed

   procedure Draw
     (LCD   : in out HAL.Bitmap.Bitmap_Buffer'Class;
      Clear : Boolean := False);

   procedure Dump_Screen (LCD : in out HAL.Bitmap.Bitmap_Buffer'Class);

end GUI;

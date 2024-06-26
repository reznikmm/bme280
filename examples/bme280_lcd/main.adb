--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Real_Time;
with Ada.Text_IO;

with Ravenscar_Time;

with STM32.Board;
with STM32.Device;
with STM32.GPIO;
with STM32.Setup;
with STM32.User_Button;

with HAL.Bitmap;
with HAL.Framebuffer;

with Display_ILI9341;
with Bitmapped_Drawing;
with BMP_Fonts;

with BME280.I2C_Sensors;

with GUI;
with GUI_Buttons;

procedure Main is
   use type Ada.Real_Time.Time;

   Sensor : BME280.I2C_Sensors.BME280_I2C_Sensor :=
     (I2C_Port    => STM32.Device.I2C_1'Access,
      I2C_Address => 16#76#,
      Calibration => <>);

   procedure Configure_Sensor;
   --  Restart sensor with new settings according to GUI state

   type Sensor_Data is record
      Temp        : BME280.Deci_Celsius;
      Humi        : BME280.Relative_Humidity;
      Press       : BME280.Pressure_Pa;
   end record;

   function Read_Sensor return Sensor_Data;

   function Min (Left, Right : Sensor_Data) return Sensor_Data is
     (Temp  => BME280.Deci_Celsius'Min (Left.Temp,  Right.Temp),
      Humi  => BME280.Relative_Humidity'Min (Left.Humi,  Right.Humi),
      Press => BME280.Pressure_Pa'Min (Left.Press, Right.Press));

   function Max (Left, Right : Sensor_Data) return Sensor_Data is
     (Temp  => BME280.Deci_Celsius'Max (Left.Temp,  Right.Temp),
      Humi  => BME280.Relative_Humidity'Max (Left.Humi,  Right.Humi),
      Press => BME280.Pressure_Pa'Max (Left.Press, Right.Press));

   type Sensor_Limits is record
      Min : Sensor_Data;
      Max : Sensor_Data;
   end record;

   procedure Make_Wider (Limits : in out Sensor_Limits);
   --  Make limits a bit wider

   procedure Print
     (LCD    : not null HAL.Bitmap.Any_Bitmap_Buffer;
      Data   : Sensor_Data);

   procedure Plot
     (LCD    : not null HAL.Bitmap.Any_Bitmap_Buffer;
      X      : Natural;
      Data   : in out Sensor_Data;
      Limits : Sensor_Limits);

   ----------------------
   -- Configure_Sensor --
   ----------------------

   procedure Configure_Sensor is
      use all type GUI.Button_Kind;

      function Oversampling
        (State : GUI_Buttons.Boolean_Array) return BME280.Oversampling_Kind;

      function Filter
        (State : GUI_Buttons.Boolean_Array) return BME280.IRR_Filter_Kind;

      ------------
      -- Filter --
      ------------

      function Filter
        (State : GUI_Buttons.Boolean_Array) return BME280.IRR_Filter_Kind
      is
         Result : BME280.IRR_Filter_Kind := BME280.Off;
      begin
         for J in State'Range loop
            exit when State (J);
            Result := BME280.IRR_Filter_Kind'Succ (Result);
         end loop;

         return Result;
      end Filter;

      ------------------
      -- Oversampling --
      ------------------

      function Oversampling
        (State : GUI_Buttons.Boolean_Array) return BME280.Oversampling_Kind
      is
         Result : BME280.Oversampling_Kind := BME280.X1;
      begin
         for J in State'Range loop
            exit when State (J);
            Result := BME280.Oversampling_Kind'Succ (Result);
         end loop;

         return Result;
      end Oversampling;

      Ok : Boolean;
   begin
      --  Consigure IRR filter and minimal incativity delay
      Sensor.Configure
        (Standby    => 0.5,
         Filter     => Filter (GUI.State (+Fi_No .. +Fi_16)),
         SPI_3_Wire => False,
         Success    => Ok);
      pragma Assert (Ok);

      --  Enable cycling of measurements with given oversamplig
      Sensor.Start
        (Mode        => BME280.Normal,
         Humidity    => Oversampling (GUI.State (+Hu_X1 .. +Hu_16)),
         Pressure    => Oversampling (GUI.State (+Pr_X1 .. +Pr_16)),
         Temperature => Oversampling (GUI.State (+Te_X1 .. +Te_16)),
         Success     => Ok);
      pragma Assert (Ok);
   end Configure_Sensor;

   ----------------
   -- Make_Wider --
   ----------------

   procedure Make_Wider (Limits : in out Sensor_Limits) is
   begin
      Limits.Min :=
        (Temp  => 0.98 * Limits.Min.Temp,
         Humi  => 0.95 * Limits.Min.Humi,
         Press => 0.999_9 * Limits.Min.Press);

      Limits.Max :=
        (Temp  => 1.02 * Limits.Max.Temp,
         Humi  => 1.05 * Limits.Max.Humi,
         Press => 1.000_1 * Limits.Max.Press);
   end Make_Wider;

   -----------
   -- Print --
   -----------

   procedure Print
     (LCD    : not null HAL.Bitmap.Any_Bitmap_Buffer;
      Data   : Sensor_Data)
   is
      use all type GUI.Button_Kind;
      use type BME280.Deci_Celsius;

      Temp  : constant String := BME280.Deci_Celsius'Image (Data.Temp / 10);
      Humi  : constant String := BME280.Relative_Humidity'Image (Data.Humi);
      Press : constant String := BME280.Pressure_Pa'Image (Data.Press);

   begin
      if GUI.State (+Te) then
         Bitmapped_Drawing.Draw_String
           (LCD.all,
            Start      => (0, 30),
            Msg        => Temp,
            Font       => BMP_Fonts.Font8x8,
            Foreground => GUI.Buttons (+Te).Color,
            Background => HAL.Bitmap.Black);
      end if;

      if GUI.State (+Hu) then
         Bitmapped_Drawing.Draw_String
           (LCD.all,
            Start      => (0, 40),
            Msg        => Humi,
            Font       => BMP_Fonts.Font8x8,
            Foreground => GUI.Buttons (+Hu).Color,
            Background => HAL.Bitmap.Black);
      end if;

      if GUI.State (+Pr) then
         Bitmapped_Drawing.Draw_String
           (LCD.all,
            Start      => (0, 50),
            Msg        => Press,
            Font       => BMP_Fonts.Font8x8,
            Foreground => GUI.Buttons (+Pr).Color,
            Background => HAL.Bitmap.Black);
      end if;
   end Print;

   ----------
   -- Plot --
   ----------

   procedure Plot
     (LCD    : not null HAL.Bitmap.Any_Bitmap_Buffer;
      X      : Natural;
      Data   : in out Sensor_Data;
      Limits : Sensor_Limits)
   is
      use all type GUI.Button_Kind;
      use type BME280.Deci_Celsius;
      use type BME280.Relative_Humidity;
      use type BME280.Pressure_Pa;

      type Pixel_Y is delta 1.0 range 0.0 .. 1024_00.0;
      --  To avoid Constraint_Error on Humidity convertion

      Y : Natural;
   begin
      Data := Min (Data, Limits.Max);
      Data := Max (Data, Limits.Min);

      if GUI.State (+Te) then
         Y := Natural
           (BME280.Deci_Celsius'Base'
             (LCD.Height * (Data.Temp - Limits.Min.Temp))
               / BME280.Deci_Celsius'Base'
                  (Limits.Max.Temp - Limits.Min.Temp));

         Y := LCD.Height - Y;
         LCD.Set_Pixel ((X, Y), HAL.Bitmap.Red);
      end if;

      if GUI.State (+Hu) then
         Y := Natural
           (Pixel_Y
             (LCD.Height * (Data.Humi - Limits.Min.Humi))
               / BME280.Relative_Humidity'Base'
                  (Limits.Max.Humi - Limits.Min.Humi));

         Y := LCD.Height - Y;
         LCD.Set_Pixel ((X, Y), HAL.Bitmap.Green);
      end if;

      if GUI.State (+Pr) then
         Y := Natural
           (BME280.Pressure_Pa'Base'
             (LCD.Height * (Data.Press - Limits.Min.Press))
               / BME280.Pressure_Pa'Base'
                  (Limits.Max.Press - Limits.Min.Press));

         Y := LCD.Height - Y;
         LCD.Set_Pixel ((X, Y), HAL.Bitmap.Blue);
      end if;
   end Plot;

   -----------------
   -- Read_Sensor --
   -----------------

   function Read_Sensor return Sensor_Data is
      Ok          : Boolean;
      Measurement : BME280.Measurement;
      Temp        : BME280.Deci_Celsius;
   begin
      Sensor.Read_Measurement (Measurement, Ok);
      pragma Assert (Ok);

      Temp := Sensor.Temperature (Measurement);

      return
        (Temp  => Temp,
         Humi  => Sensor.Humidity (Measurement, Temp),
         Press => Sensor.Pressure (Measurement, Temp));
   end Read_Sensor;

   Empty : constant Sensor_Limits :=
     (Min =>
        (Temp  => BME280.Deci_Celsius'Last,
         Humi  => BME280.Relative_Humidity'Last,
         Press => BME280.Pressure_Pa'Last),
      Max =>
        (Temp  => BME280.Deci_Celsius'First,
         Humi  => BME280.Relative_Humidity'First,
         Press => BME280.Pressure_Pa'First));

   LCD : constant not null HAL.Bitmap.Any_Bitmap_Buffer :=
     STM32.Board.TFT_Bitmap'Access;

   Next        : Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Ok          : Boolean;
   Next_Limits : Sensor_Limits;
begin
   STM32.Board.Initialize_LEDs;
   STM32.User_Button.Initialize;
   STM32.Board.Display.Initialize;
   STM32.Board.Display.Set_Orientation (HAL.Framebuffer.Landscape);
   STM32.Board.Touch_Panel.Initialize;
   STM32.Board.Touch_Panel.Set_Orientation (HAL.Framebuffer.Landscape);

   --  Initialize touch panel IRQ pin
   STM32.Board.TFT_RS.Configure_IO
     ((STM32.GPIO.Mode_In, Resistors => STM32.GPIO.Floating));

   STM32.Setup.Setup_I2C_Master
     (Port        => STM32.Device.I2C_1,
      SDA         => STM32.Device.PB9,
      SCL         => STM32.Device.PB8,
      SDA_AF      => STM32.Device.GPIO_AF_I2C1_4,
      SCL_AF      => STM32.Device.GPIO_AF_I2C1_4,
      Clock_Speed => 400_000);

   --  Look for BME280 chip
   if not Sensor.Check_Chip_Id then
      Ada.Text_IO.Put_Line ("BME280 not found.");
      raise Program_Error;
   end if;

   --  Reset BME280
   Sensor.Reset (Ravenscar_Time.Delays, Ok);
   pragma Assert (Ok);

   --  Read calibration data into Clib
   Sensor.Read_Calibration (Ok);

   Configure_Sensor;

   --  Wait for the first measurement
   Ravenscar_Time.Delays.Delay_Milliseconds
     (BME280.Max_Measurement_Time
        (Humidity    => BME280.X1,
         Pressure    => BME280.X1,
         Temperature => BME280.X1) / 1000 + 1);

   --  Predict boundaries from the first sensor measurement
   Next_Limits.Min := Read_Sensor;
   Next_Limits.Max := Next_Limits.Min;
   Make_Wider (Next_Limits);

   loop
      declare
         Limits : constant Sensor_Limits := Next_Limits;
         Data   : Sensor_Data;
         Update : Boolean := False;  --  GUI state updated
      begin
         GUI.Draw (LCD.all, Clear => True);  --  draw all buttons
         Next_Limits := Empty;

         for X in 0 .. LCD.Width - 1 loop
            STM32.Board.Toggle (STM32.Board.D1_LED);

            Data := Read_Sensor;

            Next_Limits :=
              (Min => Min (Data, Next_Limits.Min),
               Max => Max (Data, Next_Limits.Max));

            if not STM32.Board.TFT_RS.Set then  --  Touch IRQ Pin is active
               GUI.Check_Touch (STM32.Board.Touch_Panel, Update);
            end if;

            GUI.Draw (LCD.all);
            Print (LCD, Data);
            Plot (LCD, X, Data, Limits);

            if Update then
               Configure_Sensor;
               Update := False;
            elsif STM32.User_Button.Has_Been_Pressed then
               GUI.Dump_Screen (LCD.all);
            end if;

            Next := Next + Ada.Real_Time.Milliseconds (100);
            delay until Next;
         end loop;

         Make_Wider (Next_Limits);
      end;
   end loop;
end Main;

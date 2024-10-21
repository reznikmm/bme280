--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

pragma Ada_2022;

with Ada.Text_IO;

with Ravenscar_Time;

with HAL.SPI;

with STM32.Board;
with STM32.Device;
with STM32.GPIO;
with STM32.SPI;

with BME280.SPI;

procedure Main is

   SPI      renames STM32.Device.SPI_1;
   SPI_SCK  renames STM32.Device.PB3;
   SPI_MISO renames STM32.Device.PB4;
   SPI_MOSI renames STM32.Device.PB5;
   SPI_CS   renames STM32.Device.PD13;

   package BME280_SPI is new BME280.SPI
     (SPI_Port => SPI'Access,
      SPI_CS   => SPI_CS'Access);

   procedure Setup_SPI_1;

   -----------------
   -- Setup_SPI_1 --
   -----------------

   procedure Setup_SPI_1 is

      SPI_Pins : constant STM32.GPIO.GPIO_Points :=
        [SPI_SCK, SPI_MISO, SPI_MOSI, SPI_CS];
   begin
      STM32.Device.Enable_Clock (SPI_Pins);

      STM32.GPIO.Configure_IO
        (SPI_CS,
         (Mode        => STM32.GPIO.Mode_Out,
          Resistors   => STM32.GPIO.Floating,
          Output_Type => STM32.GPIO.Push_Pull,
          Speed       => STM32.GPIO.Speed_100MHz));

      SPI_CS.Set;

      STM32.GPIO.Configure_IO
        (SPI_Pins (1 .. 3),
         (Mode           => STM32.GPIO.Mode_AF,
          Resistors      => STM32.GPIO.Pull_Up,
          AF_Output_Type => STM32.GPIO.Push_Pull,
          AF_Speed       => STM32.GPIO.Speed_100MHz,
          AF             => STM32.Device.GPIO_AF_SPI1_5));

      STM32.Device.Enable_Clock (SPI);

      STM32.SPI.Configure
        (SPI,
         (Direction           => STM32.SPI.D2Lines_FullDuplex,
          Mode                => STM32.SPI.Master,
          Data_Size           => HAL.SPI.Data_Size_8b,
          Clock_Polarity      => STM32.SPI.High,   --   Mode 3
          Clock_Phase         => STM32.SPI.P2Edge,
          Slave_Management    => STM32.SPI.Software_Managed,
          Baud_Rate_Prescaler => STM32.SPI.BRP_8,
          First_Bit           => STM32.SPI.MSB,
          CRC_Poly            => 0));
      --  SPI1 sits on APB2, which is 84MHz, so SPI rate in 84/32=2.6MHz
   end Setup_SPI_1;

   Ok          : Boolean := False;
   Calib       : BME280.Calibration_Constants;
   Measurement : BME280.Measurement;
   Temp        : BME280.Deci_Celsius;
   Humi        : BME280.Relative_Humidity;
   Press       : BME280.Pressure_Pa;

begin
   STM32.Board.Initialize_LEDs;
   Setup_SPI_1;

   --  Look for BME280 chip
   if not BME280_SPI.Check_Chip_Id then
      Ada.Text_IO.Put_Line ("BME280 not found.");
      raise Program_Error;
   end if;

   --  Reset BME280
   BME280_SPI.Reset (Ravenscar_Time.Delays, Ok);
   pragma Assert (Ok);

   --  Read calibration data into Clib
   BME280_SPI.Read_Calibration (Calib, Ok);

   --  Consigure IRR filter and minimal incativity delay
   BME280_SPI.Configure
     (Standby    => 0.5,
      Filter     => BME280.X16,
      SPI_3_Wire => False,
      Success    => Ok);
   pragma Assert (Ok);

   --  Enable cycling of measurements with given oversamplig
   BME280_SPI.Start
     (Mode        => BME280.Normal,
      Humidity    => BME280.X1,
      Pressure    => BME280.X16,
      Temperature => BME280.X2,
      Success     => Ok);

   --  Wait for the first measurement
   Ravenscar_Time.Delays.Delay_Milliseconds
     (BME280.Max_Measurement_Time
        (Humidity    => BME280.X1,
         Pressure    => BME280.X16,
         Temperature => BME280.X2) / 1000 + 1);

   loop
      STM32.Board.Toggle (STM32.Board.D1_LED);

      BME280_SPI.Read_Measurement (Measurement, Ok);

      if Ok then
         --  Decode temperature, humidity and pressure
         Temp := BME280.Temperature (Measurement, Calib);
         Humi := BME280.Humidity (Measurement, Temp, Calib);
         Press := BME280.Pressure (Measurement, Temp, Calib);

         Ada.Text_IO.Put_Line
           ("T=" & Temp'Image &
              " H=" & Humi'Image &
              " P=" & Press'Image);
      end if;

      Ravenscar_Time.Delays.Delay_Milliseconds (500);
   end loop;
end Main;

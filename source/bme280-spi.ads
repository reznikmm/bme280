--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package offers a straightforward method for setting up the BME280
--  when connected via SPI, especially useful when the use of only one sensor
--  is required. If you need multiple sensors, it is preferable to use the
--  BME280.SPI_Sensors package, which provides the appropriate tagged type.

with HAL.GPIO;
with HAL.SPI;
with HAL.Time;

generic
   SPI_Port : not null HAL.SPI.Any_SPI_Port;
   SPI_CS   : not null HAL.GPIO.Any_GPIO_Point;
package BME280.SPI is

   function Check_Chip_Id (Expect : Byte := Chip_Id) return Boolean;
   --  Read the chip ID and check that it matches

   procedure Reset
     (Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean);
   --  Issue a soft reset and wait until the chip is ready.

   procedure Configure
     (Standby    : Standby_Duration := 1000.0;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean);
   --  Configure the sensor to use IRR filtering and/or SPI 3-wire mode

   procedure Start
     (Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean);
   --  Change sensor mode. Mainly used to start one measurement or enable
   --  perpetual cycling of measurements and inactive periods.

   function Measuring return Boolean;
   --  Check if a measurement is in progress

   procedure Read_Measurement
     (Value   : out Measurement;
      Success : out Boolean);
   --  Read the raw measurement values from the sensor

   procedure Read_Calibration
     (Value   : out Calibration_Constants;
      Success : out Boolean);
   --  Read the calibration constants from the sensor

end BME280.SPI;

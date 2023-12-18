--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with HAL.Time;

package BME280.Sensors is

   type Sensor is limited interface;

   function Check_Chip_Id
     (Self   : Sensor;
      Expect : HAL.UInt8 := 16#60#) return Boolean is abstract;
   --  Read the chip ID and check that it matches

   procedure Reset
     (Self    : Sensor;
      Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean) is abstract;
   --  Issue a soft reset and wait until the chip is ready.

   procedure Configure
     (Self       : Sensor;
      Standby    : Standby_Duration := 0.5;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean) is abstract;
   --  Configure the sensor to use IRR filtering and/or SPI 3-wire mode

   procedure Start
     (Self        : Sensor;
      Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean) is abstract;
   --  Change sensor mode. Mainly used to start one measurement or enable
   --  perpetual cycling of measurements and inactive periods.

   function Measuring (Self : Sensor) return Boolean is abstract;
   --  Check if a measurement is in progress

   procedure Read_Measurement
     (Self    : Sensor;
      Value   : out Measurement;
      Success : out Boolean) is abstract;
   --  Read the raw measurement values from the sensor

   function Temperature
     (Self  : Sensor;
      Value : Measurement) return Deci_Celsius is abstract;
   --  Get the temperature from raw values in 0.1 Celsius

   function Humidity
     (Self        : Sensor;
      Value       : Measurement;
      Temperature : Deci_Celsius) return Relative_Humidity is abstract;
   --  Get the humidity from raw values

   function Pressure
     (Self        : Sensor;
      Value       : Measurement;
      Temperature : Deci_Celsius) return Pressure_Pa is abstract;
   --  Get the pressure from raw values

   procedure Read_Calibration
     (Self    : in out Sensor;
      Success : out Boolean) is abstract;
   --  Read the calibration constants from the sensor

end BME280.Sensors;

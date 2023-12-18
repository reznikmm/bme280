--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package provides a type representing the BME280 connected via the I2C
--  interface.

with HAL.I2C;
with HAL.Time;

with BME280.Sensors;

package BME280.I2C_Sensors is

   Default_Address : constant HAL.UInt7 := 16#76#;
   --  The typical BME280 7-bit I2C address

   type BME280_I2C_Sensor
     (I2C_Port    : not null HAL.I2C.Any_I2C_Port;
      I2C_Address : HAL.UInt7) is limited new BME280.Sensors.Sensor with
   record
      Calibration : Calibration_Constants;
   end record;

   overriding function Check_Chip_Id
     (Self   : BME280_I2C_Sensor;
      Expect : HAL.UInt8 := 16#60#) return Boolean;
   --  Read the chip ID and check that it matches

   overriding procedure Reset
     (Self    : BME280_I2C_Sensor;
      Timer   : not null HAL.Time.Any_Delays;
      Success : out Boolean);
   --  Issue a soft reset and wait until the chip is ready.

   overriding procedure Configure
     (Self       : BME280_I2C_Sensor;
      Standby    : Standby_Duration := 0.5;
      Filter     : IRR_Filter_Kind := Off;
      SPI_3_Wire : Boolean := False;
      Success    : out Boolean);
   --  Configure the sensor to use IRR filtering and/or SPI 3-wire mode

   overriding procedure Start
     (Self        : BME280_I2C_Sensor;
      Mode        : Sensor_Mode := Normal;
      Humidity    : Oversampling_Kind := X1;
      Pressure    : Oversampling_Kind := X1;
      Temperature : Oversampling_Kind := X1;
      Success     : out Boolean);
   --  Change sensor mode. Mainly used to start one measurement or enable
   --  perpetual cycling of measurements and inactive periods.

   overriding function Measuring (Self : BME280_I2C_Sensor) return Boolean;
   --  Check if a measurement is in progress

   overriding procedure Read_Measurement
     (Self    : BME280_I2C_Sensor;
      Value   : out Measurement;
      Success : out Boolean);
   --  Read the raw measurement values from the sensor

   overriding function Temperature
     (Self  : BME280_I2C_Sensor;
      Value : Measurement) return Deci_Celsius is
        (Temperature (Value, Self.Calibration));
   --  Get the temperature from raw values in 0.1 Celsius

   overriding function Humidity
     (Self        : BME280_I2C_Sensor;
      Value       : Measurement;
      Temperature : Deci_Celsius) return Relative_Humidity is
        (Humidity (Value, Temperature, Self.Calibration));
   --  Get the humidity from raw values

   overriding function Pressure
     (Self        : BME280_I2C_Sensor;
      Value       : Measurement;
      Temperature : Deci_Celsius) return Pressure_Pa is
        (Pressure (Value, Temperature, Self.Calibration));
   --  Get the pressure from raw values

   overriding procedure Read_Calibration
     (Self    : in out BME280_I2C_Sensor;
      Success : out Boolean);
   --  Read the calibration constants from the sensor

end BME280.I2C_Sensors;

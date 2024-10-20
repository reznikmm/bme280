--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

generic
   type Device_Context (<>) is limited private;

   with procedure Read
     (Device  : Device_Context;
      Data    : out Byte_Array;
      Success : out Boolean);
   --  Read the values from the BME280 chip registers into Data.
   --  Each element in the Data corresponds to a specific register address
   --  in the chip, so Data'Range determines the range of registers to read.
   --  The value read from register X will be stored in Data(X), so
   --  Data'Range should be of the Register_Address subtype.

   with procedure Write
     (Device  : Device_Context;
      Address : Register_Address;
      Data    : Byte;
      Success : out Boolean);
   --  Write the value to the BME280 chip register with given Address.

package BME280.Internal is

   function Check_Chip_Id
     (Device : Device_Context;
      Expect : Byte) return Boolean;
   --  Read the chip ID and check that it matches

   procedure Reset
     (Device  : Device_Context;
      Timer   : not null access procedure (Millisecond : Positive);
      Success : out Boolean);
   --  Issue a soft reset and wait until the chip is ready.

   procedure Configure
     (Device     : Device_Context;
      Standby    : Standby_Duration;
      Filter     : IRR_Filter_Kind;
      SPI_3_Wire : Boolean;
      Success    : out Boolean);
   --  Configure the sensor to use IRR filtering and/or SPI 3-wire mode

   procedure Start
     (Device      : Device_Context;
      Mode        : Sensor_Mode;
      Humidity    : Oversampling_Kind;
      Pressure    : Oversampling_Kind;
      Temperature : Oversampling_Kind;
      Success     : out Boolean);
   --  Change sensor mode. Mainly used to start one measurement or enable
   --  perpetual cycling of measurements and inactive periods.

   function Measuring (Device  : Device_Context) return Boolean;
   --  Check if a measurement is in progress

   procedure Read_Measurement
     (Device  : Device_Context;
      Value   : out Measurement;
      Success : out Boolean);
   --  Read the raw measurement values from the sensor

   procedure Read_Calibration
     (Device  : Device_Context;
      Value   : out Calibration_Constants;
      Success : out Boolean);
   --  Read the calibration constants from the sensor

end BME280.Internal;

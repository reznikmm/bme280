--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package offers a straightforward method for setting up the BME280
--  when connected via I2C, especially useful when the use of only one sensor
--  is required. If you need multiple sensors, it is preferable to use the
--  BME280.I2C_Sensors package, which provides the appropriate tagged type.

with HAL.I2C;

with BME280.Generic_Sensor;

generic
   I2C_Port    : not null HAL.I2C.Any_I2C_Port;
   I2C_Address : HAL.UInt7 := 16#76#;  --  The BME280 7-bit I2C address
package BME280.I2C is

   procedure Read
     (Data    : out HAL.UInt8_Array;
      Success : out Boolean);
   --  Read registers starting from Data'First

   procedure Write
     (Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean);
   --  Write the value to the BME280 chip register with given Address.

   package Sensor is new Generic_Sensor (Read, Write);

end BME280.I2C;

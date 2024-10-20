--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package provides a low-level interface for interacting with the
--  sensor. Communication with the sensor is done by reading/writing one
--  or more bytes to predefined registers. The interface allows the user to
--  implement the read/write operations in the way they prefer but handles
--  encoding/decoding register values into user-friendly formats.
--
--  For each request to the sensor, the interface defines a subtype-array
--  where the index of the array element represents the register number to
--  read/write, and the value of the element represents the corresponding
--  register value.
--
--  Functions starting with `Set_` prepare values to be written to the
--  registers. Conversely, functions starting with `Get_` decode register
--  values. Functions starting with `Is_` are a special case for boolean
--  values.
--
--  The user is responsible for reading and writing register values!

package BME280.Raw is

   use type Interfaces.Integer_16;
   use type Interfaces.Unsigned_8;

   subtype Chip_Id_Data is Byte_Array (16#D0# .. 16#D0#);
   --  ID register

   function Get_Chip_Id (Raw : Byte_Array) return Byte is
     (Raw (Chip_Id_Data'First));
   --  Read the chip ID. Raw data should contain Chip_Id_Data'First item.

   Set_Reset : constant Byte_Array := (16#E0# => 16#B6#);
   --  Request the complete power-on-reset procedure.
   --
   --  Wait until Is_Updating = False to complete reset.

   subtype Configuration_Data is Byte_Array (16#F5# .. 16#F5#);
   --  Config register

   function Set_Configuration
     (Standby    : Standby_Duration;
      Filter     : IRR_Filter_Kind;
      SPI_3_Wire : Boolean) return Configuration_Data;
   --  Encode sensor configuration to use IRR filtering and/or SPI 3-wire mode

   subtype Mode_Data is Byte_Array (16#F2# .. 16#F4#);
   --  Control registers (ctrl_hum, ctrl_meas). Only first and last bytes
   --  matter.

   function Set_Mode
     (Mode        : Sensor_Mode;
      Humidity    : Oversampling_Kind;
      Pressure    : Oversampling_Kind;
      Temperature : Oversampling_Kind) return Mode_Data;
   --  Change sensor mode request. Mainly used to start one measurement or
   --  enable perpetual cycling of measurements and inactive periods.

   subtype Status_Data is Byte_Array (16#F3# .. 16#F3#);
   --  Status register

   function Is_Measuring (Raw : Byte_Array) return Boolean is
     ((Raw (Status_Data'First) and 8) /= 0);
   --  Check if a measurement is in progress

   function Is_Updating (Raw : Byte_Array) return Boolean is
     ((Raw (Status_Data'First) and 1) /= 0);
   --  Check if the NVM data are being copied to image registers

   subtype Measurement_Data is Byte_Array (16#F7# .. 16#FE#);
   --  The raw pressure, temperature, humidity measurement output data

   function Get_Measurement (Raw : Byte_Array) return Measurement;
   --  Decode raw measurement output data. Raw data should contain
   --  Measurement_Data'Range items.

   type Calibration_Constants_Data is record
      Data_1 : Byte_Array (16#88# .. 16#A1#);
      Data_2 : Byte_Array (16#E1# .. 16#E7#);
   end record;
   --  The raw calibration constants

   function Get_Calibration_Constants
     (Raw : Calibration_Constants_Data) return Calibration_Constants;
   --  Decode raw calibration constants. Raw data should contain
   --  Calibration_Constants_Data'Range items.

   function Is_Reseting (Raw : Byte_Array) return Boolean renames Is_Updating;
   --  Call this to see if reset procedure in progress

   function SPI_Write (X : Register_Address) return Byte is
     (Byte (X) and 16#7F#);
   --  For write operation on the SPI bus the register address is passed with
   --  the highest bit off (0).

   function SPI_Read (X : Register_Address) return Byte is
     (Byte (X) or 16#80#);
   --  For read operation on the SPI bus the register address is passed with
   --  the highest bit on (1).

   function SPI_Write (X : Byte_Array) return Byte_Array is
     (if X'Length = 1 then SPI_Write (X'First) & X
      else SPI_Write (X'First) & X (X'First) & SPI_Write (X'Last) & X (X'Last))
        with Pre => X'Length in 1 | 3;
   --  Prefix the byte array with the register address for the SPI write
   --  operation. There is no autoincrement for writes. Each byte should
   --  be prefixed with a register address.

   function SPI_Read (X : Byte_Array) return Byte_Array is
     ((X'First - 1 => SPI_Read (X'First)) & X);
   --  Prefix the byte array with the register address for the SPI read
   --  operation

   function I2C_Write (X : Byte_Array) return Byte_Array is
     (if X'Length = 1 then Byte (X'First) & X
      else Byte (X'First) & X (X'First) & Byte (X'Last) & X (X'Last))
        with Pre => X'Length in 1 | 3;
   --  Prefix the byte array with the register address for the I2C write
   --  operation. There is no autoincrement for writes. Each byte should
   --  be prefixed with a register address.

   function I2C_Read (X : Byte_Array) return Byte_Array renames I2C_Write;
   --  Prefix the byte array with the register address for the I2C read
   --  operation

end BME280.Raw;

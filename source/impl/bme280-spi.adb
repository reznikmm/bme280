--  SPDX-FileCopyrightText: 2023 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

package body BME280.SPI is

   ----------
   -- Read --
   ----------

   procedure Read
     (Data    : out HAL.UInt8_Array;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Addr : HAL.UInt8;
      Status : HAL.SPI.SPI_Status;
   begin
      SPI.SPI_CS.Clear;

      Addr := HAL.UInt8 (Data'First) or 16#80#;
      SPI_Port.Transmit (HAL.SPI.SPI_Data_8b'(1 => Addr), Status);

      if Status = Ok then
         SPI_Port.Receive (HAL.SPI.SPI_Data_8b (Data), Status);
      end if;

      SPI.SPI_CS.Set;

      Success := Status = Ok;
   end Read;

   -----------
   -- Write --
   -----------

   procedure Write
     (Address : Register_Address;
      Data    : HAL.UInt8;
      Success : out Boolean)
   is
      use type HAL.UInt8;
      use all type HAL.SPI.SPI_Status;

      Prefix : constant HAL.UInt8 := HAL.UInt8 (Address) and 16#7F#;
      Status : HAL.SPI.SPI_Status;
   begin
      SPI.SPI_CS.Clear;

      SPI_Port.Transmit (HAL.SPI.SPI_Data_8b'(Prefix, Data), Status);

      SPI.SPI_CS.Set;

      Success := Status = Ok;
   end Write;

end BME280.SPI;

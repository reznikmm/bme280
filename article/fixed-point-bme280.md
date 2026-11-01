# Fixed point types in Ada: BME280 compensation without floats and magic shifts

The BME280 is a popular temperature, pressure and humidity sensor. It does
not return ready values: it gives raw ADC readings plus a set of
factory calibration coefficients, and the driver has to run a few
compensation formulas. Bosch publishes these formulas in the
[BME280_SensorAPI](https://github.com/boschsensortec/BME280_SensorAPI)
in two flavours: one on `double`, and one on integers full of shifts
and magic constants.

When I wrote my [Ada driver](https://github.com/reznikmm/bme280) I
started from the integer version. This post is about rewriting it with
Ada fixed point types, and about what this costs and gains in accuracy
and code size.

## Fixed point types in a nutshell

Ada has two kinds of fixed point types.

An *ordinary* fixed point type is declared with a `delta` and a range:

```ada
type Volts is delta 1.0 / 2**8 range 0.0 .. 5.0;
```

A *decimal* fixed point type is declared with a `delta` (a power of ten)
and a number of `digits`:

```ada
type Money is delta 0.01 digits 14;
```

Both are, under the hood, plain integers. Each type has a *small*: the
value of one unit of the underlying integer. A `Volts` value of `3.5` is
stored as the integer `3.5 * 2**8 = 896`. The compiler picks the size
of the integer from the range and the small: `Volts` needs 11 bits, so it
fits in 16.

The difference between the two kinds is the small:

* For a decimal type the small is exactly the `delta`, a power of ten.
  Values like `0.01` are exact, there are rules for rounding, picture
  editing for output, and the whole thing is aimed at money and other
  business data.
* For an ordinary type the small is by default the largest power of two
  not greater than the `delta`, so multiplication and division by the
  small become shifts. A different small can be given with the `Small`
  aspect, but for embedded code power-of-two smalls are what you want.

Arithmetic follows simple rules:

* `+` and `-` work within one type.
* A fixed point value can be multiplied or divided by an `Integer`, the
  result has the same type.
* Any two fixed point values can be multiplied or divided. The result
  has no type of its own (it is "universal fixed"), so it must land in a
  context that gives it one: an assignment, a conversion or a qualified
  expression. The compiler then generates the right integer
  multiplication and the right shift.

The last rule is the interesting one. It means you describe *what* each
quantity is (its range and precision), and the compiler works out *how*
to scale every product. That is exactly the bookkeeping the Bosch
integer code does by hand.

## The temperature formula

Here is the Bosch `double` version of the temperature compensation
(clamping removed):

```c
var1 = (((double)uncomp_data->temperature) / 16384.0 - ((double)calib_data->dig_t1) / 1024.0);
var1 = var1 * ((double)calib_data->dig_t2);
var2 = (((double)uncomp_data->temperature) / 131072.0 - ((double)calib_data->dig_t1) / 8192.0);
var2 = (var2 * var2) * ((double)calib_data->dig_t3);
calib_data->t_fine = (int32_t)(var1 + var2);
temperature = (var1 + var2) / 5120.0;
```

And the integer one:

```c
var1 = (int32_t)((uncomp_data->temperature / 8) - ((int32_t)calib_data->dig_t1 * 2));
var1 = (var1 * ((int32_t)calib_data->dig_t2)) / 2048;
var2 = (int32_t)((uncomp_data->temperature / 16) - ((int32_t)calib_data->dig_t1));
var2 = (((var2 * var2) / 4096) * ((int32_t)calib_data->dig_t3)) / 16384;
calib_data->t_fine = var1 + var2;
temperature = (calib_data->t_fine * 5 + 128) / 256;
```

If you strip away the scaling, the formula is a simple polynomial. With
`X = ADC / 2**14 - T1 / 2**10` the temperature is
`X * T2 + X**2 * T3` up to some power-of-two factors. In Horner form:
`X * (T2 + X * T3)`.

### Step 1: put the scaling into the coefficient types

Every calibration coefficient gets its own fixed point type. The small is
chosen so that the raw register value *is* the internal integer, and the
type's value is already scaled for the formula:

```ada
package Calibration_Register is
   type T1 is delta 2.0**(-10) range 0.0 .. 2.0**6 - 2.0**(-10);
   type T2 is delta 2.0**(-9) range -2.0**6 .. 2.0**6 - 2.0**(-9);
   type T3 is delta 2.0**(-15) range -1.0 .. 1.0 - 2.0**(-15);
   ...
end Calibration_Register;
```

A 16-bit register value `R` becomes a coefficient with
`T2'Small * R`: no shifts, no conversion code, the bits are just
reinterpreted.

### Step 2: pick a unit for the result

The driver returns temperature in `Deci_Celsius`:

```ada
type Deci_Celsius is delta 1.0 / 2 ** 9 range -99_0.00 .. 99_0.00;
--  1 degree celsius is 10 Deci_Celsius
```

Its small is `1/512` of a deci-degree, so the internal integer of a
`Deci_Celsius` value is exactly Bosch's `t_fine`
(`t_fine / 5120` degrees). The pressure and humidity formulas, which use
`t_fine`, can take this value as is.

### Step 3: write the formula

```ada
function Temperature
  (Value       : Measurement;
   Calibration : Calibration_Constants) return Deci_Celsius
is
   --  X = ADC / 2**14 - T1
   --  T = X * (T2 + X * T3)   (in deci-celsius)
   type ADC is delta 2.0**(-14) range -2.0**7 .. 2.0**7;
   type Slope is delta 2.0**(-20) range -2.0**8 .. 2.0**8;
   type Wide is delta 2.0**(-9) range -2.0**16 .. 2.0**16;

   C : Calibration_Constants renames Calibration;

   T1 : constant ADC := ADC (C.T1);
   T2 : constant Slope := Slope (C.T2);

   Diff   : constant ADC := ADC'Small * Value.Raw_Temp - T1;
   Result : constant Wide := Diff * (T2 + Diff * C.T3);

   Min : constant Wide := Wide (Deci_Celsius'First);
   Max : constant Wide := Wide (Deci_Celsius'Last);

begin
   return Deci_Celsius (Wide'Max (Min, Wide'Min (Result, Max)));
end Temperature;
```

The formula line reads like the math. The local types `ADC`, `Slope`
and `Wide` say how big and how precise each intermediate value is, and
that is all the information the compiler needs. There is not a single
magic number or shift in the code.

The same approach works for the other two formulas. Pressure, for
example, becomes:

```ada
--  T = Temperature - 25.0 C (in deci-celsius)
--  P = (2**20 - ADC - (P4 + T * (P5 + T * P6)))
--        * 6250 / (P1 * (1 + T * (P2 + T * P3)))
--  Pa = P7 + P * (1 + P8 + P * P9)
```

and each line of this comment maps to one line of Ada.

### Keeping it 32-bit

My first version used generous intermediate types, some of them wider
than 32 bits. On a Cortex-M this is expensive: GNAT multiplies two
64-bit fixed point values through `System.Arith_64.Scaled_Divide64`,
a runtime routine. Narrowing every intermediate type to 32 bits made
all these calls go away. A product of two 32-bit values is then a single
`smull` instruction (32×32→64 bits, one cycle on Cortex-M4), followed by
a shift. The accuracy hardly changed.

One 64-bit operation is left: the division in the pressure formula. The
result is around 10⁵ Pa and I want precision well below 1 Pa, which
needs a dividend wider than 32 bits, while Cortex-M4 can only divide
32 by 32 bits in hardware. The Bosch 64-bit integer version has the same
division.

## Comparison

All numbers below are produced by the script at the end of this post.

### Accuracy

The reference is the Bosch `double` version. I took the calibration data
of three real sensors and swept a grid of raw ADC values over the
physical range of the sensor (−40…85 °C, 300…1100 hPa, 0…100 %),
381 596 points in total. This runs natively on x86_64.

| Version | Temperature, °C (max / RMS) | Pressure, Pa (max / RMS) | Humidity, % (max / RMS) |
|---|---|---|---|
| Bosch, 64-bit integer | 0.015 / 0.0068 | 0.055 / 0.024 | 0.0074 / 0.0034 |
| Bosch, 32-bit integer | 0.015 / 0.0068 | 6.5 / 1.8 | 0.0074 / 0.0034 |
| Ada, fixed point | 0.0002 / 0.0001 | 0.015 / 0.0064 | 0.0028 / 0.0015 |

Part of the difference is just the resolution of the result: the Bosch
integer code returns temperature in 0.01 °C, the Ada code in 1/5120 °C.
But the pressure and humidity results have comparable resolution, and
the fixed point version is still several times closer to `double`. The
reason is that every intermediate type keeps as many fractional bits as
fit, while the hand-written integer code drops bits in a chain of
divisions.

To be fair, none of this matters for the sensor itself: its absolute
accuracy is about ±1 °C, ±1 hPa and ±3 % RH.

### Code for a microcontroller

The second part compiles each version for an STM32F4 (Cortex-M4F) with
the GNAT FSF 16.1 arm-elf toolchain at `-O2`. The Ada code is compiled
with `pragma Restrictions (No_Floating_Point)`, so the compiler confirms
that no floating point sneaks in.

Totals for the three functions:

| Version | Bytes | Instructions | Runtime calls |
|---|---|---|---|
| Bosch, `double` | 1264 | 444 | 97 soft-float calls |
| Bosch, 64-bit integer | 882 | 290 | 1× `__aeabi_ldivmod` |
| Bosch, 32-bit integer | 594 | 199 | — |
| Ada, fixed point | 768 | 248 | 1× `__aeabi_ldivmod` |
| Ada, fixed point, with run-time checks | 1552 | 496 | 1× `__aeabi_ldivmod` |

Per function:

| Function | Bytes | Instructions | mul (32-bit result) | mul (64-bit result) | div | Calls |
|---|---|---|---|---|---|---|
| C double: temperature | 296 | 107 | 0 | 0 | 0 | 18 soft-float |
| C double: pressure | 588 | 205 | 0 | 0 | 0 | 48 soft-float |
| C double: humidity | 380 | 132 | 0 | 0 | 0 | 31 soft-float |
| C int64: temperature | 120 | 41 | 3 | 0 | 0 | — |
| C int64: pressure | 576 | 184 | 16 | 10 | 0 | `__aeabi_ldivmod` |
| C int64: humidity | 186 | 65 | 8 | 0 | 0 | — |
| C int32: temperature | 120 | 41 | 3 | 0 | 0 | — |
| C int32: pressure | 288 | 93 | 10 | 0 | 2 | — |
| C int32: humidity | 186 | 65 | 8 | 0 | 0 | — |
| Ada: temperature | 96 | 33 | 0 | 2 | 0 | — |
| Ada: pressure | 376 | 121 | 4 | 8 | 0 | `__aeabi_ldivmod` |
| Ada: humidity | 296 | 94 | 2 | 9 | 0 | — |

Some observations:

* The `double` version is the largest and the slowest by far.
  Cortex-M4F has only a single precision FPU, so every `double`
  operation is a call into the soft-float library, whose code is not
  even counted here.
* The fixed point version is smaller than the Bosch 64-bit integer
  version overall, and noticeably smaller for temperature and pressure.
* Humidity is the exception: the Ada code is larger than Bosch's. The
  Bosch integer humidity formula works with 32-bit products only, at
  the price of lower accuracy. The Ada version uses 32×32→64 products,
  and GNAT rounds each scaled product toward zero, which costs a few
  extra instructions per multiplication for negative values.
* The Bosch 32-bit integer version is the smallest, but its pressure is
  off by up to 6.5 Pa, two orders of magnitude worse than the other
  integer and fixed point versions.
* With run-time checks enabled the Ada code doubles in size: every
  conversion to a constrained type is checked for overflow. Whether you
  need them is a separate decision. Here the ranges of the intermediate
  types were checked by testing with `-gnata -gnato`, which raised no
  `Constraint_Error`.
* These are instruction counts, not cycles. Instruction counts
  understate the cost of the `double` version, because each soft-float
  call is dozens of instructions.

## Conclusion

Fixed point types let you write the compensation formulas the way they
are written in math, keep all scaling in type declarations, and let the
compiler generate the integer code. In this case the result is both
simpler to read and more accurate than the hand-written integer version,
with similar or smaller code.

The price is that you have to think about the range and precision of
each intermediate value, and on a 32-bit microcontroller it pays to keep
these types within 32 bits.

## Reproducing the results

The benchmark consists of four files:

* `run.sh` downloads the GNAT FSF 16.1 toolchains (native and arm-elf)
  unless you point it to existing ones, clones both repositories at
  fixed commits, and runs everything.
* `reference.c` wraps the Bosch `bme280.c`. It is compiled three times,
  for the `double`, 64-bit and 32-bit variants.
* `compare_accuracy.adb` sweeps the raw values and prints the accuracy
  table.
* `analyze_object.py` disassembles the object files and counts
  instructions per function.

```sh
./run.sh
# or with existing toolchains:
GNAT_NATIVE_DIRECTORY=... GNAT_ARM_DIRECTORY=... ./run.sh
```

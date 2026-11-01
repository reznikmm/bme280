/*  Wrapper around the official Bosch BME280_SensorAPI compensation code.
 *
 *  The file is compiled three times with different macros:
 *    -DBME280_DOUBLE_ENABLE -DREFERENCE_FUNCTION=reference_double
 *    -DBME280_64BIT_ENABLE  -DREFERENCE_FUNCTION=reference_integer_64
 *    -DBME280_32BIT_ENABLE  -DREFERENCE_FUNCTION=reference_integer_32
 *
 *  The compensate_* functions in bme280.c are static, so we include the
 *  whole bme280.c here and export a single function. All results are
 *  converted to degrees Celsius, pascals and percent of relative humidity.
 */
#include "bme280.c"

void REFERENCE_FUNCTION(const uint8_t *calibration_registers_88_a1,
                        const uint8_t *calibration_registers_e1_e7,
                        uint32_t raw_pressure,
                        uint32_t raw_temperature,
                        uint32_t raw_humidity,
                        double *result,
                        int32_t *temperature_fine)
{
    struct bme280_dev device = {0};
    struct bme280_uncomp_data raw = {raw_pressure, raw_temperature, raw_humidity};

    parse_temp_press_calib_data(calibration_registers_88_a1, &device);
    parse_humidity_calib_data(calibration_registers_e1_e7, &device);

#if defined(BME280_DOUBLE_ENABLE)
    result[0] = compensate_temperature(&raw, &device.calib_data);
    result[1] = compensate_pressure(&raw, &device.calib_data);
    result[2] = compensate_humidity(&raw, &device.calib_data);
#elif defined(BME280_32BIT_ENABLE)
    result[0] = compensate_temperature(&raw, &device.calib_data) / 100.0;
    result[1] = compensate_pressure(&raw, &device.calib_data);          /* Pa */
    result[2] = compensate_humidity(&raw, &device.calib_data) / 1024.0;
#else
    result[0] = compensate_temperature(&raw, &device.calib_data) / 100.0;
    result[1] = compensate_pressure(&raw, &device.calib_data) / 100.0;  /* Pa * 100 */
    result[2] = compensate_humidity(&raw, &device.calib_data) / 1024.0;
#endif

    *temperature_fine = device.calib_data.t_fine;
}

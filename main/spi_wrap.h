#pragma once
#include "driver/spi_master.h"
#include <stdint.h>

#define SPI_TASK_STACK_SIZE 3072

// SPI sizes in bits
#define SPI_COMMAND_SIZE 0
#define SPI_ADDRESS_SIZE 0
#define SPI_DUMMY_SIZE   0

#define SPI_FREQ (1 * 100 * 1000) // 100 khz
/**
 * @param data to send
 */
void setup_and_run_spi(void *args);
#pragma once
#include "driver/spi_master.h"
#include <stdint.h>

// SPI sizes in bits
#define SPI_COMMAND_SIZE 0
#define SPI_ADDRESS_SIZE 0
#define SPI_DUMMY_SIZE   0

/**
 * @param data to send
 */
void setup_and_run_spi(void *args);
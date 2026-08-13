#pragma once
#include <stdint.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

typedef struct {
    uint8_t CMND;
    uint8_t ADDR;
    uint16_t DATA;
} UART_to_SPI_message_t;

typedef struct {
    // Cmnd
    uint8_t CMD : 8;
    // Addr
    uint8_t MATRIX_TYPE : 2; // 2 bits
    uint8_t ROW_IDX : 1;
    uint8_t COL_IDX : 1;
    uint8_t RESERVED : 2;
    uint8_t TAG : 2;
    // Data
    uint8_t DATA_UPPER : 8;
    uint8_t DATA_LOWER : 8;
} matrix_command_t;

typedef union {
    matrix_command_t fields;
    uint32_t word;
} matrix_command_u;

// Queue handle - handle in main.c
extern QueueHandle_t uart_to_spi_queue;
extern QueueHandle_t matrix_to_spi_queue;
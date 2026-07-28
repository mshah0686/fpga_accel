#pragma once
#include <stdint.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

typedef struct {
    uint8_t CMND;
    uint8_t ADDR;
    uint16_t DATA;
} UART_to_SPI_message_t;

// Queue handle
extern QueueHandle_t uart_to_spi_queue;
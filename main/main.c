#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "uart_wrap.h"
#include "spi_wrap.h"
#include "common_queues.h"

static const char* MAIN_TAG = "MAIN";

// Define the variable once here
QueueHandle_t uart_to_spi_queue = NULL; 

static void setup_queues(void) {
    uart_to_spi_queue = xQueueCreate(10, sizeof(UART_to_SPI_message_t));

    if(uart_to_spi_queue == NULL) {
        ESP_LOGI(MAIN_TAG, "Could not create queue!");
    }

    return;
}

void app_main(void)
{
    // Commone communication interfaces
    setup_queues();

    ESP_LOGI(MAIN_TAG, "Starting threads....");

    // UART TASK on Core 0
    xTaskCreatePinnedToCore(
        setup_uart_and_run,
        "uart_wrap_task",
        UART_TASK_STACK_SIZE,
        NULL,
        1, // priority
        NULL,
        0 // Core 0
    );

    // SPI TASK on Core 0
    xTaskCreatePinnedToCore(
        setup_and_run_spi,
        "spi_wrap_task",
        SPI_TASK_STACK_SIZE,
        NULL,
        1, // priority
        NULL,
        0 // Core 0
    );
}

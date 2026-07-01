// UART capability

#include "driver/uart.h"
#include "sdkconfig.h"
#include "esp_log.h"
#include <stdio.h>
#include <string.h>
#include "uart_wrap.h"
#include "common_queues.h"

// Logger
static const char *TAG = "UART";

// UART Read data
static uint8_t uart_read_data[UART_BUF_SIZE];

// Configuration for UART
static uart_config_t uart_config = {
    .baud_rate = UART_BAUDRATE,
    .data_bits = UART_DATA_8_BITS,
    .parity    = UART_PARITY_DISABLE,
    .stop_bits = UART_STOP_BITS_1,
    .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
    .source_clk = UART_SCLK_DEFAULT,
};

// Do initial pin setup
static void setup_uart() {
    int intr_alloc_flags = 0;

    // SETUP UART
    ESP_ERROR_CHECK(uart_set_pin(HARDWARE_UART_PORT, HARDWARE_UART_TX_PIN, HARDWARE_UART_RX_PIN, TEST_RTS, TEST_CTS));
    ESP_ERROR_CHECK(uart_driver_install(HARDWARE_UART_PORT, 129, 0, 0, NULL, intr_alloc_flags));
    ESP_ERROR_CHECK(uart_param_config(HARDWARE_UART_PORT, &uart_config));

    return;
}

static void run_uart_poll() {
    ESP_LOGI(TAG, "UART_POLL_START....");
    UART_to_SPI_message_t message;

    while (1) {
        // Read data from the UART
        int len = uart_read_bytes(
                HARDWARE_UART_PORT,  // PORT defined in setup
                &uart_read_data,  // Buffer to read
                (UART_BUF_SIZE - 1),  // Buffer size to read (last bit is for \n)
                0); // Period to wait (either exit on buffer full or hold task for this long) - 0 means no wait just grab

        // Write data back to the UART
        if (len) {
            uart_read_data[len] = '\0';
            ESP_LOGI(TAG, "Recv str: %s", (char *) uart_read_data);

            message.data = uart_read_data[0];
            if (xQueueSend(uart_to_spi_queue, &message, pdMS_TO_TICKS(10)) != pdPASS) {
                ESP_LOGI(TAG, "Could not send message! %s", (char *) uart_read_data);
            }
            // Wait for next input
            vTaskDelay(pdMS_TO_TICKS(1000));
        }
    }
}


// Setup and run UART reading forever loop
void setup_uart_and_run(void *args) {
    setup_uart();
    ESP_LOGI(TAG, "UART_SETUP....OK");

    run_uart_poll();
}
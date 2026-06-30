// UART capability

#include "driver/uart.h"
#include "driver/gpio.h"
#include "sdkconfig.h"
#include "esp_log.h"
#include <stdio.h>
#include <string.h>
#include "uart.h"

// Logger
static const char *TAG = "UART";

// Configuration for UART
static uart_config_t uart_config = {
    .baud_rate = ECHO_UART_BAUD_RATE,
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
    ESP_ERROR_CHECK(uart_set_pin(DEBUG_UART_PORT, ECHO_TEST_TXD, ECHO_TEST_RXD, ECHO_TEST_RTS, ECHO_TEST_CTS));
    ESP_ERROR_CHECK(uart_driver_install(DEBUG_UART_PORT, 129, 0, 0, NULL, intr_alloc_flags));
    ESP_ERROR_CHECK(uart_param_config(DEBUG_UART_PORT, &uart_config));

    return;
}

static void run_uart_poll() {
    ESP_LOGI(TAG, "UART_POLL_START....");
    while(1) {
        // POLL UART
    }
}


// Setup and run UART reading forever loop
void setup_uart_and_run(void *args) {
    setup_uart();
    ESP_LOGI(TAG, "UART_SETUP....OK");

    run_uart_poll();
}
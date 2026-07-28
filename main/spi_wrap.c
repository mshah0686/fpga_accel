#include <stdint.h>
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "spi_wrap.h"
#include "hardware.h"
#include "common_queues.h"
#include "esp_log.h"

static const char *TAG = "SPI";

spi_bus_config_t spi_cfg = {
    .miso_io_num = SPI_MISO_PIN,
    .mosi_io_num = SPI_MOSI_PIN,
    .sclk_io_num = SPI_CLK_PIN,
    .quadwp_io_num = -1,       // Not used for standard 4-wire SPI
    .quadhd_io_num = -1,       // Not used for standard 4-wire SPI
    .max_transfer_sz = 4    // Maximum transfer size in bytes
};

spi_device_interface_config_t dev_cfg = {
    .command_bits = SPI_COMMAND_SIZE,
    .address_bits = SPI_ADDRESS_SIZE,
    .dummy_bits = 0,
    .clock_speed_hz = SPI_FREQ, // Clock speed: 10 MHz
    .mode = 0,                          // SPI Mode 0 (CPOL=0, CPHA=0)
    .spics_io_num = SPI_CS_PIN,         // Chip Select GPIO pin
    .queue_size = 7,                    // How many transactions can queue at once
};

// Device handle to send data
spi_device_handle_t spi_device;

// Setup SPI
static void setup_spi_interface(void) {
    // Setup
    esp_err_t ret = spi_bus_initialize(
        SPI_HOST, 
        &spi_cfg, 
        SPI_DMA_CH_AUTO);

    ESP_ERROR_CHECK(ret);

    ret = spi_bus_add_device(SPI_HOST, &dev_cfg, &spi_device);
    ESP_ERROR_CHECK(ret);
}

void send_spi_transaction(UART_to_SPI_message_t data) {
    esp_err_t ret;
    spi_transaction_t t;
    uint8_t buf[4] = {
        data.CMND,
        data.ADDR,
        (uint8_t) (data.DATA >> 8),
        (uint8_t) (data.DATA & 0xFF)
    };

    memset(&t, 0, sizeof(t));
    t.length = 32;                   // Total transaction length in BITS
    t.tx_buffer = &buf;               // Data to send (or poitner based on flags)
    t.rx_buffer = NULL;              // Pointer to buffer for data in

    // This blocks the task until transmission completes
    ret = spi_device_transmit(spi_device, &t);
    ESP_ERROR_CHECK(ret);
}

void setup_and_run_spi(void *args) {
    setup_spi_interface();
    ESP_LOGI(TAG, "SPI_SETUP....OK");

    UART_to_SPI_message_t input_message;

    while(1) {
        if(xQueueReceive(uart_to_spi_queue, &input_message, pdMS_TO_TICKS(10)) == pdPASS) {
            ESP_LOGI(TAG, "Sending %0x", input_message.DATA);
            send_spi_transaction(input_message);
        } else {
            // Delay a bit for next data input
            vTaskDelay(pdMS_TO_TICKS(1));
        }
    }
}
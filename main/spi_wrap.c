#include <stdint.h>
#include <string.h>
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "spi_wrap.h"
#include "hardware.h"
#include "common_queues.h"
#include "esp_log.h"

static const char *TAG = "SPI";

static spi_bus_config_t spi_cfg = {
    .miso_io_num = SPI_MISO_PIN,
    .mosi_io_num = SPI_MOSI_PIN,
    .sclk_io_num = SPI_CLK_PIN,
    .quadwp_io_num = -1,       // Not used for standard 4-wire SPI
    .quadhd_io_num = -1,       // Not used for standard 4-wire SPI
    .max_transfer_sz = 4    // Maximum transfer size in bytes
};

static spi_device_interface_config_t dev_cfg = {
    .command_bits = SPI_COMMAND_SIZE,
    .address_bits = SPI_ADDRESS_SIZE,
    .dummy_bits = 0,
    .clock_speed_hz = SPI_FREQ, // Clock speed: 10 MHz
    .mode = 0,                          // SPI Mode 0 (CPOL=0, CPHA=0)
    .spics_io_num = SPI_CS_PIN,         // Chip Select GPIO pin
    .queue_size = 7,                    // How many transactions can queue at once
};

// Device handle to send data
static spi_device_handle_t spi_device;

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

static void send_spi_transaction(uint32_t data) {
    esp_err_t ret;
    spi_transaction_t t;
    uint8_t buf[4] = {
        (uint8_t) (data & 0xFF),
        (uint8_t) ((data >> 8) & 0xFF),
        (uint8_t) ((data >> 16) & 0xFF),
        (uint8_t) ((data >> 24) & 0xFF)
    };
    uint8_t rx_buf[4] = {0};

    memset(&t, 0, sizeof(t));
    t.length = 32;                   // Total transaction length in BITS
    t.tx_buffer = buf;               // Data to send (or poitner based on flags)
    t.rx_buffer = rx_buf;            // Pointer to buffer for data in

    // This blocks the task until transmission completes
    ret = spi_device_transmit(spi_device, &t);
    ESP_ERROR_CHECK(ret);
    ESP_LOGI(TAG, "TX bytes: %02X %02X %02X %02X",
             buf[0], buf[1], buf[2], buf[3]);


    if(rx_buf[1] == 0) {
        ESP_LOGI(TAG, "RX Result: %02X %02X",
            rx_buf[2], rx_buf[3]);
    } else {
        ESP_LOGI(TAG, "NO VALID_READ: RX bytes: %02X %02X %02X %02X",
             rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3]);
    }

}

void setup_and_run_spi(void *args) {
    setup_spi_interface();
    ESP_LOGI(TAG, "SPI_SETUP....OK");

    matrix_command_u input_message;

    while(1) {
        // Block until work arrives. Do NOT use a short pdMS_TO_TICKS() timeout here:
        // at CONFIG_FREERTOS_HZ=100 anything under 10ms truncates to 0 ticks, which
        // turns this into a busy-spin that starves IDLE0 and trips the task watchdog.
        if(xQueueReceive(matrix_to_spi_queue, &input_message, portMAX_DELAY) == pdPASS) {
            send_spi_transaction(input_message.word);
        }
    }
}
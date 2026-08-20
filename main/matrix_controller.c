#include <stdint.h>
#include "esp_log.h"
#include "matrix_controller.h"
#include "common_queues.h"

static const char *TAG = "MATRIX";

static void send_SPI_command(
    uint8_t _cmd,
    uint8_t _matrix_type,
    uint8_t _row_idx,
    uint8_t _col_idx,
    uint16_t _data
) {
    matrix_command_u command;
    command.fields.CMD = _cmd;
    command.fields.MATRIX_TYPE = _matrix_type;
    command.fields.ROW_IDX = _row_idx;
    command.fields.COL_IDX = _col_idx;
    command.fields.RESERVED = 0;
    command.fields.TAG = MATRIX_PERIPHERAL_TAG;
    command.fields.DATA_UPPER = _data >> 8;
    command.fields.DATA_LOWER = _data & 0xFF;

    ESP_LOGI(TAG,
        "cmd=%d type=%d row=%d col=%d reserved=%d tag=%d data_upper=0x%02X data_lower=0x%02X (word=0x%08X)",
        command.fields.CMD,
        command.fields.MATRIX_TYPE,
        command.fields.ROW_IDX,
        command.fields.COL_IDX,
        command.fields.RESERVED,
        command.fields.TAG,
        (unsigned) command.fields.DATA_UPPER,
        (unsigned) command.fields.DATA_LOWER,
        (unsigned) command.word);
    
    if (xQueueSend(matrix_to_spi_queue, &command, pdMS_TO_TICKS(10)) != pdPASS) {
        ESP_LOGI(TAG, "Could not send message! 0x%0x", (uint32_t) command.word);
    }
}

static void run_matrix_loop(uint8_t seed) {

    for (int r = 0; r < 2; r++) {
        for(int c = 0; c < 2; c++) {
            uint16_t data = (2 * r) + c;
            data = data + seed;
            send_SPI_command(WRITE, MATRIX_TYPE_A, r, c, data);
        }
    }

    for (int r = 0; r < 2; r++) {
        for(int c = 0; c < 2; c++) {
            uint16_t data = (2 * r) + c + 4;
            data = data + seed;
            send_SPI_command(WRITE, MATRIX_TYPE_B, r, c, data);
        }
    }

    // Enable compute
    uint16_t compute_enable = 1;
    send_SPI_command(WRITE, MATRIX_CTRL, 0, 0, compute_enable);

    // Read request
    uint16_t read_req = 0;
    send_SPI_command(READ, MATRIX_CTRL, 0, 0, read_req);
    
    for (int r = 0; r < 2; r++) {
        for(int c = 0; c < 2; c++) {
            // Read result
            send_SPI_command(READ, MATRIX_TYPE_C, r, c, 0);
        }
    }

    // Last read
    send_SPI_command(NOP, 0, 0, 0, 0);
}

// Setup and run UART reading forever loop
void setup_matrix_and_run(void *args) {
    ESP_LOGI(TAG, "MATRIX_SETUP....OK");

    uint8_t static_input_message;

    while(1) {
        if(xQueueReceive(uart_trigger_queue, &static_input_message, pdMS_TO_TICKS(10)) == pdPASS) {
            run_matrix_loop(static_input_message);
        } else {
            vTaskDelay(pdMS_TO_TICKS(1));
        }
    }
}
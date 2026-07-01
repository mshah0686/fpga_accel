#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "uart_wrap.h"

static const char* MAIN_TAG = "MAIN";

void app_main(void)
{
    ESP_LOGI(MAIN_TAG, "Starting threads....");
    xTaskCreate(setup_uart_and_run, "uart_wrap_task", UART_TASK_STACK_SIZE, NULL, 10, NULL);
}

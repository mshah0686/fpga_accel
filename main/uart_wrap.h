/* 
    Header define for uart handling
*/

#pragma once
#include <stdint.h>
#include "hardware.h"

#define TEST_RTS (UART_PIN_NO_CHANGE) // Unused
#define TEST_CTS (UART_PIN_NO_CHANGE) // Unused
#define UART_BAUDRATE     115200
#define UART_TASK_STACK_SIZE 3072
#define UART_BUF_SIZE 2 // Bytes to read per poll

/**
 * @brief: Set up UART pins, directions, and start polling for inputs
 * 
 * @return void
 */
void setup_uart_and_run(void *args);


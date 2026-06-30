/* 
    Header define for uart handling
*/

#pragma once
#include <stdint.h>
#include "hardware.h"


#define TX_PIN (HARDWARE_TX_PIN)
#define RX_PIN 3

#define DEBUG_UART_PORT 0

#define ECHO_UART_BAUD_RATE     115200
#define ECHO_TASK_STACK_SIZE    (CONFIG_EXAMPLE_TASK_STACK_SIZE) // Gotten from compilation
#define BUF_SIZE 2 // Gotten from compilation

/**
 * @brief: Set up UART pins, directions, and start polling for inputs
 * 
 * @return void
 */
void setup_uart_and_run(void *args);


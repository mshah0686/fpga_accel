#pragma once

#include <stdint.h>

#define MATRIX_TASK_STACK_SIZE 3072

// Hardware register fields
#define MATRIX_PERIPHERAL_TAG 0b11
#define MATRIX_TYPE_A 0b00
#define MATRIX_TYPE_B 0b01
#define MATRIX_TYPE_C 0b10
#define MATRIX_CTRL 0b11

// Hardware Commands
#define NOP 0
#define READ 1
#define WRITE 2

/**
 * @brief: Set up UART pins, directions, and start polling for inputs
 * 
 * @return void
 */
void setup_matrix_and_run(void *args);
// List of common configurations
`ifndef FPGA_TYPES_V
`define FPGA_TYPES_V

// TXN WIDTHS
`define CMD_WIDTH  8
`define ADDR_WIDTH 8
`define ADDR_PERIF_TAG_WIDTH 2 // Peripheral ID (LSB of address)
`define ADDR_REG_WIDTH `ADDR_WIDTH - `ADDR_PERIF_TAG_WIDTH // Within peripheral
`define DATA_WIDTH 16
`define TXN_WIDTH  (`CMD_WIDTH + `ADDR_WIDTH + `DATA_WIDTH)

// COMMANDS
`define CMD_NOP    `CMD_WIDTH'd0
`define CMD_READ   `CMD_WIDTH'd1
`define CMD_WRITE  `CMD_WIDTH'd2

// ADDRESSES
`define TIMER_TAG `ADDR_PERIF_TAG_WIDTH'd0
`define TIMER_CTRL_REG `ADDR_REG_WIDTH'd0

// TIMER_COMMANDS
`define TIMER_CLEAR `DATA_WIDTH'd0
`define TIMER_START `DATA_WIDTH'd1
`define TIMER_STOP  `DATA_WIDTH'd2

// MATRIX MULT
`define MATRIX_SIZE 2
`define MATRIX_TAG `ADDR_PERIF_TAG_WIDTH'b11
`define MATRIX_TYPE_WIDTH 2
`define MATRIX_IDX_WIDTH 1 // ROW/COL ADDR
`define MATRIX_RESERVED_WIDTH 2

`define MATRIX_A `MATRIX_TYPE_WIDTH'd0
`define MATRIX_B `MATRIX_TYPE_WIDTH'd1
`define MATRIX_C `MATRIX_TYPE_WIDTH'd2
`define MATRIX_CONTROL `MATRIX_TYPE_WIDTH'd3

// MATRIX ADDRESS INDEXING
// ADDR = 8 Bits
// [2 bits - Matrix TYPE][ 1 bits - ROW IDX][1 bits - Col Idx][2'b00 Reserved][11 Peripheral TAG]
// Matrix TYPE: 0 -> A, 1, -> B, 2 -> C, 3 -> CTRL
// 1 bits Row Idx -> 0, 1
// 2 bits Col idx -> 0, 1
// 4 bits 0b1111 -> Matrix encoding



`endif

// List of common configurations
`ifndef FPGA_TYPES_V
`define FPGA_TYPES_V

// TXN WIDTHS - 32 bits each
`define CMD_WIDTH  2
`define TAG_WIDTTH 2
`define ADDR_WIDTH 10
`define DATA_WIDTH 16
`define TXN_WIDTH  (`CMD_WIDTH + `TAG_WIDTTH + `ADDR_WIDTH + `DATA_WIDTH)

// COMMANDS
`define CMD_NOP    `CMD_WIDTH'd0
`define CMD_READ   `CMD_WIDTH'd1
`define CMD_WRITE  `CMD_WIDTH'd2

`define PIXEL_TAG 0
`define MATRIX_TAG 1

`endif

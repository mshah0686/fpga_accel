// List of common configurations
`ifndef FPGA_TYPES_V
`define FPGA_TYPES_V

// TXN WIDTHS
`define CMD_WIDTH  8
`define ADDR_WIDTH 8
`define DATA_WIDTH 16
`define TXN_WIDTH  (`CMD_WIDTH + `ADDR_WIDTH + `DATA_WIDTH)

// COMMANDS
`define CMD_NOP    `CMD_WIDTH'd0
`define CMD_WRITE  `CMD_WIDTH'd1
`define CMD_READ   `CMD_WIDTH'd2

// ADDRESSES
`define TIMER_ADDR `ADDR_WIDTH'd1

// TIMER_COMMANDS
`define TIMER_CLEAR `DATA_WIDTH'd0
`define TIMER_START `DATA_WIDTH'd1
`define TIMER_STOP  `DATA_WIDTH'd2

`endif

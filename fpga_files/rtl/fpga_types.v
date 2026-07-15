// List of common configurations

// TXN WIDTHS
parameter CMD_WIDTH = 8;
parameter ADDR_WIDTH = 8;
parameter DATA_WIDTH = 16;
parameter TXN_WIDTH = CMD_WIDTH + ADDR_WIDTH + DATA_WIDTH;

// COMMANDS
parameter [CMD_WIDTH-1:0] CMD_NOP = 0;
parameter [CMD_WIDTH-1:0] CMD_WRITE = 1;
parameter [CMD_WIDTH-1:0] CMD_READ = 1;

// ADDRESSES
parameter [ADDR_WIDTH-1:0] TIMER_ADDR = 0;

// TIMER_COMMANDS
parameter [DATA_WIDTH-1:0] TIMER_CLEAR = 0;
parameter [DATA_WIDTH-1:0] TIMER_START = 1;
parameter [DATA_WIDTH-1:0] TIMER_STOP = 2;

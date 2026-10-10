// List of common configurations
package fpga_params;

    localparam CMD_WIDTH = 2;
    localparam TAG_WIDTH = 2;
    localparam RESERVED_WIDTH = 2;
    localparam ADDR_WIDTH = 10;
    localparam DATA_WIDTH = 16;
    localparam TXN_WIDTH = (CMD_WIDTH + RESERVED_WIDTH + TAG_WIDTH + ADDR_WIDTH + DATA_WIDTH);

    // COMMANDS
    localparam logic [CMD_WIDTH-1:0] CMD_NOP = 'd0;
    localparam logic [CMD_WIDTH-1:0] CMD_READ = 'd1;
    localparam  logic [CMD_WIDTH-1:0] CMD_WRITE = 'd2;

    localparam PIXEL_TAG = 0;
    localparam MATRIX_TAG  = 1;

    // Interface sizes
    localparam PIXEL_PER_WRITE = 2;

endpackage

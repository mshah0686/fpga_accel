// Holds multiple BRAM instances and wraps them
module bram_wrapper #(
    parameter N = 2,
    parameter BRAM_SIZE = 4,
    parameter DATA_WIDTH = 8,

    parameter PRELOAD = 0,
    parameter LOAD_FILE_PREFIX = "",

    localparam ADDR_WIDTH = $clog2(BRAM_SIZE),
    localparam ARRAY_WIDTH = $clog2(N)
) (
    input clk,

    input [N-1:0] r_en,
    input [N-1:0][ADDR_WIDTH-1:0] r_addr,
    output [N-1:0][DATA_WIDTH-1:0] r_data,

    input [N-1:0] w_en,
    input [N-1:0][ADDR_WIDTH-1:0] w_addr,
    input [N-1:0][DATA_WIDTH-1:0] w_data

);

    // TODO: Implement BRAM array using genvar



endmodule
module matrix_mult_top #(
    // Data widths of matrices
    parameter A_DATA_WIDTH = 8,
    parameter B_DATA_WIDTH = 8,
    parameter ACC_WIDTH = 26,

    // Matrix sizes MxK * KxN
    parameter M = 2,
    parameter K = 2,
    parameter N = 2,

    localparam MAX_DATA_WIDTH = (A_DATA_WIDTH > B_DATA_WIDTH) ? A_DATA_WIDTH : B_DATA_WIDTH, // Compute done at this data width
    localparam ADDR_WIDTH = $clog2(K), // Address within BRAM (K entries)

    parameter signed [M-1:0][N-1:0][ACC_WIDTH-1:0] MAC_BIAS = 'd0
)(
    input clk,

    // Control
    input go_pulse,
    output idle,

    // RESULT
    output result_valid,
    output [M-1:0][N-1:0][ACC_WIDTH-1:0] result,

    // A Matrix BRAM
    output [M-1:0] A_value_bram_r_en,
    output [M-1:0][ADDR_WIDTH-1:0] A_value_bram_r_addr,
    input [M-1:0][MAX_DATA_WIDTH-1:0] A_value_bram_r_data,

    // B Matrix BRAM
    output [N-1:0] B_value_bram_r_en,
    output [N-1:0][ADDR_WIDTH-1:0] B_value_bram_r_addr,
    input [N-1:0][MAX_DATA_WIDTH-1:0] B_value_bram_r_data
);

    // Controller <-> datapath control signals
    wire load_outputs;
    wire execute;
    wire datapath_idle;
    wire controller_idle;

    // Control register out

    matrix_mult_controller u_controller (
        .clk (clk),
        .req_valid (go_pulse), // Pulse beat in
        .execute (execute),
        .load_outputs (load_outputs),
        .datapath_idle (datapath_idle),
        .controller_idle (idle)
    );

    mult_datapath #(
        .DATA_WIDTH(MAX_DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .M   (M),
        .K   (K),
        .N   (N),
        .MAC_BIAS(MAC_BIAS)
    ) u_datapath (
        .clk (clk),
        .execute (execute),
        .load_outputs (load_outputs),
        .idle (datapath_idle),

        // Output matrix
        .c_out_valid  (result_valid),
        .c_out        (result),

        // BRAM
        .A_req_addr(A_value_bram_r_addr),
        .A_req_en(A_value_bram_r_en),
        .A_req_data(A_value_bram_r_data),

        .B_req_addr(B_value_bram_r_addr),
        .B_req_en(B_value_bram_r_en),
        .B_req_data(B_value_bram_r_data)
    );

endmodule

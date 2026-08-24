module matrix_mult_top #(
    parameter D_WIDTH = 8,
    parameter ACC_WIDTH = 26,
    parameter M = 2,
    parameter K = 2,
    parameter N = 2,
    parameter REG_WIDTH = 16
)(
    input clk,

    // Matrix control register interface (to/from register model)
    input  [REG_WIDTH-1:0] matrix_control_in, // LSB valid beat to enable it
    output [REG_WIDTH-1:0] matrix_control_out,

    // Matrix operands (2x2, indexed [row][col])
    input  [M-1:0][K-1:0][D_WIDTH-1:0]   a,
    input  [K-1:0][N-1:0][D_WIDTH-1:0]   b,

    // Matrix result (2x2, indexed [row][col])
    output [M-1:0][N-1:0][ACC_WIDTH-1:0] c
);

    // Controller <-> datapath control signals
    wire load_outputs;
    wire execute;
    wire datapath_idle;
    wire controller_idle;

    // Controller input/output & status
    wire matrix_top_idle;
    wire req_valid = matrix_control_in[0]; // Pulse in

    // Control register out
    assign matrix_control_out = {{(REG_WIDTH-1){1'd0}}, controller_idle};

    matrix_mult_controller u_controller (
        .clk          (clk),
        .req_valid    (req_valid), // Pulse beat in
        .execute      (execute),
        .load_outputs (load_outputs),
        .datapath_idle   (datapath_idle),
        .controller_idle         (controller_idle)
    );

    mult_datapath #(
        .D_WIDTH   (D_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .M   (M),
        .K   (K),
        .N   (N)
    ) u_datapath (
        .clk          (clk),
        .execute      (execute),
        .load_outputs (load_outputs),
        .idle         (datapath_idle),
        .a            (a),
        .b            (b),
        .c_out        (c)
    );

endmodule

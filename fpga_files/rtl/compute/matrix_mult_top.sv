module matrix_mult_top #(
    parameter D_WIDTH    = 8,
    parameter ACC_WIDTH  = 16,
    parameter CTRL_WIDTH = 16
)(
    input clk,

    // Matrix control register interface (to/from register model)
    input  [CTRL_WIDTH-1:0] matrix_control_in, // LSB valid beat to enable it
    output [CTRL_WIDTH-1:0] matrix_control_out,

    // Matrix operands (2x2, indexed [row][col])
    input  [1:0][1:0][D_WIDTH-1:0]   a,
    input  [1:0][1:0][D_WIDTH-1:0]   b,

    // Matrix result (2x2, indexed [row][col])
    output [1:0][1:0][ACC_WIDTH-1:0] c,

    output [2:0] dbg
);

    // Controller <-> datapath control signals
    wire load_values;
    wire execute;
    wire load_outputs;
    wire dpath_idle;

    // Controller input/output & status
    wire multiplier_idle;
    wire req_valid = matrix_control_in[0]; // Pulse in

    // Control register out
    assign matrix_control_out = {15'd0, multiplier_idle};

    matrix_mult_controller u_controller (
        .clk          (clk),
        .req_valid    (req_valid), // Pulse beat in
        .load_values  (load_values),
        .execute      (execute),
        .load_outputs (load_outputs),
        .dpath_idle   (dpath_idle),
        .idle         (multiplier_idle)
    );

    mult_datapath #(
        .D_WIDTH   (D_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_datapath (
        .clk          (clk),
        .load_values  (load_values),
        .execute      (execute),
        .load_outputs (load_outputs),
        .idle         (dpath_idle),
        .a            (a),
        .b            (b),
        .c_out        (c)
    );

    assign dbg = {execute, load_outputs, dpath_idle, multiplier_idle};

endmodule

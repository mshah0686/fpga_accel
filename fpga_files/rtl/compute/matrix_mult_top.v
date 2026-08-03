module matrix_mult_top #(
    parameter D_WIDTH = 4,
    parameter ACC_WIDTH = 16
)(
    input clk,
    input req_valid,
    output done,

    // Matrix A / B inputs
    input  [D_WIDTH-1:0] a00, a01, a10, a11,
    input  [D_WIDTH-1:0] b00, b01, b10, b11,

    // Matrix C output
    output [ACC_WIDTH-1:0] c00, c01, c10, c11
);

    // Controller -> datapath control signals
    wire load_values;
    wire select_k;
    wire enable;
    wire clear;
    wire load_outputs;

    matrix_mult_controller u_controller (
        .clk          (clk),
        .req_valid    (req_valid),
        .load_values  (load_values),
        .select_k     (select_k),
        .enable       (enable),
        .clear        (clear),
        .load_outputs (load_outputs),
        .done         (done)
    );

    mult_datapath #(
        .D_WIDTH   (D_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_datapath (
        .clk          (clk),
        .load_values  (load_values),
        .select_k     (select_k),
        .enable       (enable),
        .clear        (clear),
        .load_outputs (load_outputs),
        .a00 (a00), .a01 (a01), .a10 (a10), .a11 (a11),
        .b00 (b00), .b01 (b01), .b10 (b10), .b11 (b11),
        .c00 (c00), .c01 (c01), .c10 (c10), .c11 (c11)
    );

endmodule

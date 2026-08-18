// MAC implementation block

module systolic_mac #(
    parameter D_WIDTH   = 8,
    parameter ACC_WIDTH = 24
)(
    input clk,

    input  [D_WIDTH-1:0] a_in,
    input  [D_WIDTH-1:0] b_in,
    input                valid_a_in, // Both should be valid on same cycle...can remove this to opimize
    input                valid_b_in,
    input                first_in_a, // First compute
    input                first_in_b,

    output reg [D_WIDTH-1:0] a_out,
    output reg [D_WIDTH-1:0] b_out,
    output reg               valid_a_out,
    output reg               valid_b_out,
    output reg               first_a_out,
    output reg               first_b_out,

    output [ACC_WIDTH-1:0] c_out
);

    reg [ACC_WIDTH-1:0] acc;

    wire valid = valid_a_in & valid_b_in;

    always @(posedge clk) begin
        // pass operands + validity to neighbors, one cycle later
        a_out       <= a_in;
        b_out       <= b_in;
        valid_a_out <= valid_a_in;
        valid_b_out <= valid_b_in;
        first_a_out <= first_in_a;
        first_b_out <= first_in_b;

        // Valid inputs
        if (valid) begin
            if(first_in_a || first_in_b)
                acc <= (a_in * b_in);
            else
                acc <= acc + (a_in * b_in);
        end

    end

    assign c_out = acc;

endmodule
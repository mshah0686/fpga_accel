module sync_flops #(
    parameter SIZE=4
)
(
    input clk,
    input [SIZE:0] in,
    output reg [SIZE:0] out
);

    reg [SIZE:0] q_1 = {SIZE{0}};

    always @(posedge clk) begin
        q_1 <= in;
        out <= q_1;
    end

endmodule
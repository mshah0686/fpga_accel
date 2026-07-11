module sync_flops #(
    parameter SIZE=8
)
(
    input clk,
    input [SIZE-1:0] in,
    output reg [SIZE-1:0] out
);

    reg [SIZE-1:0] q_1;

    always @(posedge clk) begin
        q_1 <= in;
        out <= q_1;
    end

endmodule
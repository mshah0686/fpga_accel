// Module to choose from SIZE inputs
// Output index with maximum

module argmax #(
    parameter SIZE = 10,
    parameter WIDTH = 32,

    localparam SIZE_WIDTH = $clog2(SIZE)
) (
    input clk,
    input [SIZE -1: 0][WIDTH-1:0] inputs,
    output [SIZE_WIDTH-1:0] index_of_max
);

    logic [SIZE_WIDTH-1:0] max_idx;
    logic signed [WIDTH-1:0] max_value;
    integer i;
    always_comb begin
        max_value = inputs[0];
        max_idx = 0;
        for(i = 0; i < SIZE; i++) begin
            if($signed(inputs[i]) > max_value) begin
                max_value = $signed(inputs[i]);
                max_idx = i[SIZE_WIDTH-1:0];
            end
        end
    end

    assign index_of_max = max_idx;

endmodule 
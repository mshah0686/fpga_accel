module requantize #(
    parameter INPUT_WIDTH = 32,
    parameter OUTPUT_WIDTH = 16,
    parameter INPUT_SCALE_N = 21,
    parameter OUTPUT_SCALE_N = 8,

    parameter ARRAY_WIDTH = 1,
    parameter ARRAY_HEIGHT = 16
)(
    input [ARRAY_HEIGHT-1:0][ARRAY_WIDTH-1:0][INPUT_WIDTH-1:0] arr_in,
    output reg [ARRAY_HEIGHT-1:0][ARRAY_WIDTH-1:0][OUTPUT_WIDTH-1:0] arr_out
);

    localparam SHIFT = INPUT_SCALE_N - OUTPUT_SCALE_N;

    integer r;
    integer c;
    always_comb begin
        for(r = 0; r < ARRAY_HEIGHT; r++) begin
            for(c = 0; c < ARRAY_WIDTH; c++) begin
                arr_out[r][c] = OUTPUT_WIDTH'(arr_in[r][c] >> SHIFT);
            end
        end
    end

endmodule
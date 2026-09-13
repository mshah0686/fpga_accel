module relu #(
    parameter DATA_SIZE = 32,
    parameter ARRAY_COLS = 1,
    parameter ARRAY_ROWS = 16
) (
    input [ARRAY_ROWS-1:0][ARRAY_COLS-1:0][DATA_SIZE-1:0] arr_in,

    output logic [ARRAY_ROWS-1:0][ARRAY_COLS-1:0][DATA_SIZE-1:0] arr_out
);

    // Combinational relU calculation
    integer r;
    integer c;
    always_comb begin
        for(r = 0; r < ARRAY_ROWS; r ++ ) begin
            for(c = 0; c < ARRAY_COLS; c ++ ) begin
                arr_out[r][c] = arr_in[r][c][DATA_SIZE-1] == 1'b1 ? 'd0 : arr_in[r][c];
            end
        end
    end

endmodule
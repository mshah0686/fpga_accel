// Holds multiple BRAM instances and wraps them
module bram_wrapper #(
    parameter N = 2,
    parameter BRAM_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter OUTDATA_WIDTH = 8, // Output data at this width (must be greater than DATAWIDTH)
    parameter SIGN_EXTEND = 0, // Sign extend value or no
    parameter PRELOAD = 0,
    parameter LOAD_FILE_PREFIX = "",

    localparam ADDR_WIDTH = $clog2(BRAM_SIZE),
    localparam ARRAY_WIDTH = $clog2(N),
    localparam DATA_EXTEND_WIDTH = OUTDATA_WIDTH - DATA_WIDTH
) (
    input clk,

    input [N-1:0] r_en,
    input [N-1:0][ADDR_WIDTH-1:0] r_addr,
    output logic [N-1:0][OUTDATA_WIDTH-1:0] r_data,

    input [N-1:0] w_en,
    input [N-1:0][ADDR_WIDTH-1:0] w_addr,
    input [N-1:0][DATA_WIDTH-1:0] w_data

);

    // TODO: Implement BRAM array using genvar
    wire [N-1:0][DATA_WIDTH-1:0] r_data_out;

    genvar bram_idx;

    generate
        for(bram_idx = 0; bram_idx < N; bram_idx ++ ) begin : bram_gen
            single_port_bram #(
                .SIZE(BRAM_SIZE),
                .DATA_WIDTH(DATA_WIDTH),
                .PRELOAD(PRELOAD),
                .LOAD_FILE($sformatf("%s_%0d.hex", LOAD_FILE_PREFIX, bram_idx))
            ) bram_u (
                .clk(clk),
                .r_en(r_en[bram_idx]),
                .r_addr(r_addr[bram_idx]),
                .r_data(r_data_out[bram_idx]),

                .w_en(w_en[bram_idx]),
                .w_addr(w_addr[bram_idx]),
                .w_data(w_data[bram_idx])
            );
        end
    endgenerate

    integer k;
    always_comb begin 
        for(k = 0; k < N; k ++ ) begin
            r_data[k] = {{DATA_EXTEND_WIDTH{SIGN_EXTEND ? r_data_out[k][DATA_WIDTH-1] : 1'b0}}, r_data_out[k]};
        end
    end



endmodule
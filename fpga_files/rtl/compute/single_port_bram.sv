module single_port_bram #(
    parameter SIZE = 4,
    parameter DATA_WIDTH = 8, 
    parameter PRELOAD = 0,
    parameter LOAD_FILE = "",
    parameter WRITE_WIDTH = DATA_WIDTH, // WRITE data on this width
    parameter WRITE_SCALE = 1, // How many addresses written at once
    localparam ADDR_WIDTH = $clog2(SIZE)
)(
    input clk,

    input r_en,
    input [ADDR_WIDTH-1:0] r_addr,
    output [DATA_WIDTH-1:0] r_data,

    input w_en,
    input [ADDR_WIDTH-1:0] w_addr,
    input [WRITE_WIDTH-1:0] w_data
);

    logic [DATA_WIDTH-1:0] storage [SIZE-1:0];

    // Preload if defined
    if (PRELOAD == 1) begin : preload_block
        initial begin
            if (LOAD_FILE != "") begin
                $readmemh(LOAD_FILE, storage);
            end
        end
    end
    
    integer k;
    always_ff @(posedge clk) begin
        if(w_en) begin
            for(int k = 0; k < WRITE_SCALE; k++) begin
                storage[ADDR_WIDTH'(w_addr + k)] <= w_data[(DATA_WIDTH * k)+: DATA_WIDTH];
            end
        end
    end

    assign r_data = r_en ? storage[r_addr] : 'd0;

endmodule
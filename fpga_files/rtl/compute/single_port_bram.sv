module single_port_bram #(
    parameter SIZE = 4,
    parameter DATA_WIDTH = 8, 
    parameter PRELOAD = 0,
    parameter LOAD_FILE = "",
    localparameter ADDR_WIDTH = $clog2(SIZE)
)(
    input clk,

    input r_en,
    input [ADDR_WIDTH-1:0] r_addr,
    output [DATA_WIDTH-1:0] r_data,

    input w_en,
    input [ADDR_WIDTH-1:0] w_addr,
    input [DATA_WIDTH-1:0] w_data
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
    
    always_ff @(posedge clk) begin
        if(w_en) begin
            storage[w_addr] <= w_data;
        end
    end

    assign r_data = r_en ? storage[r_addr] : 'd0;

endmodule
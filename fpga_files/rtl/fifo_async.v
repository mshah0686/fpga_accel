module async_fifo #(
    parameter DEPTH = 4,
    parameter DATA_WIDTH = 8
) (
    input w_en,
    input [DATA_WIDTH-1:0] w_data,
    input w_clk,
    output fifo_full,

    input r_en,
    output [DATA_WIDTH-1:0] r_data,
    input r_clk,
    output fifo_empty,

    output [3:0] led_dbg_read,
    output [3:0] led_dbg_write
);

    parameter PTR_WIDTH_M_1 = $clog2(DEPTH);

    // FIFO MEMORY
    reg [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    // Read Domain:
    reg[PTR_WIDTH_M_1:0] r_read_ptr = {PTR_WIDTH_M_1{1'b0}};
    wire[PTR_WIDTH_M_1:0] r_write_gray_ptr;
    wire[PTR_WIDTH_M_1:0] r_read_gray_code_out; // Signal to cross CDC


    // Write Domain:
    reg[PTR_WIDTH_M_1:0] w_write_ptr =  {PTR_WIDTH_M_1{1'b0}};
    wire[PTR_WIDTH_M_1:0] w_read_gray_ptr;
    wire[PTR_WIDTH_M_1:0] w_write_gray_code_out; // Signal to cross CDC

    /****** READ DOMAIN: ******/
    bin2gray#(.SIZE(PTR_WIDTH_M_1)) read_bin2gray (
        .bin_in(r_read_ptr),
        .gray_out(r_read_gray_code_out)
    );

    sync_flops#(.SIZE(PTR_WIDTH_M_1)) wr_2_rd_sync (
        .clk(r_clk),
        .in(w_write_gray_code_out),
        .out(r_write_gray_ptr)
    );

    wire [PTR_WIDTH_M_1 -1 : 0] read_bucket;
    assign read_bucket = r_read_ptr[PTR_WIDTH_M_1-1:0];

    always @(posedge r_clk) begin
        if(r_en & ~fifo_empty) begin
            r_read_ptr <= r_read_ptr + 1;
        end
    end

    assign led_dbg_read[1:0] = read_bucket[1:0];
    assign fifo_empty = (r_write_gray_ptr == r_read_gray_code_out);
    assign r_data = r_en ? fifo_mem[read_bucket] : {DATA_WIDTH{1'b0}};

    /****** WRITE DOMAIN: ******/
    bin2gray#(.SIZE(PTR_WIDTH_M_1)) write_bin2gray (
        .bin_in(w_write_ptr),
        .gray_out(w_write_gray_code_out)
    );

    sync_flops#(.SIZE(PTR_WIDTH_M_1)) rd_2_wr_sync (
        .clk(w_clk),
        .in(r_read_gray_code_out),
        .out(w_read_gray_ptr)
    );

    // Memory locaiton to write in fifo
    wire [PTR_WIDTH_M_1 -1 : 0] write_bucket;
    assign write_bucket = w_write_ptr[PTR_WIDTH_M_1-1:0];
    
    wire wr_en_masked;
    assign wr_en_masked = w_en & ~fifo_full;

    always @(posedge w_clk) begin
        if(wr_en_masked) begin
            w_write_ptr <= w_write_ptr + 1;
            fifo_mem[write_bucket] <= w_data;
        end
    end
    
    assign led_dbg_write[1:0] = write_bucket[1:0];
    wire [PTR_WIDTH_M_1:0] gray_write_compare;
    assign gray_write_compare = {~w_write_gray_code_out[PTR_WIDTH_M_1:PTR_WIDTH_M_1-1], w_write_gray_code_out[PTR_WIDTH_M_1-2:0]};
    assign fifo_full = (gray_write_compare == w_read_gray_ptr);

endmodule

// 2 New modules
// 1. Bin2Gray converter (size_parameter) (combinational)
// 2. Gray2Bin converter (combinational)
// 3. two_flop_sync (size parameter)

// Decode SPI commands to downstream
module register_model 
import fpga_params::*;
import pipe_params::*;
(
    input clk,

    // Packet inputs
    input in_valid,
    input in_wr_en,
    input [TAG_WIDTH-1:0] in_tag,
    input [DATA_WIDTH-1:0] in_data,
    input [ADDR_WIDTH-1:0] in_addr,

    // MULT CONTROL
    output reg pixel_write_enable,
    output reg [PIXEL_PER_WRITE-1:0][HIDDEN_PIXEL_WIDTH-1:0] pixel_write_data,
    output reg [ADDR_WIDTH-1:0] pixel_write_address,

    output reg [15:0] matrix_control_out,
    input [15:0] matrix_result_in,
    input [15:0] matrix_status_in,

    // Read data output to fifo
    output reg out_rd_valid,
    output reg [DATA_WIDTH-1:0] out_rd_data
);

    always_ff @(posedge clk) begin
        pixel_write_enable <= 1'b0;
        matrix_control_out <= 'b0;
        
        if(in_valid && in_wr_en) begin
            if(in_tag == PIXEL_TAG) begin
                pixel_write_enable <= 1'b1;
                pixel_write_address <= ADDR_WIDTH'(in_addr);
                for (int i = 0; i < PIXEL_PER_WRITE; i++) begin
                    pixel_write_data[i] <= in_data[i*HIDDEN_PIXEL_WIDTH +: HIDDEN_PIXEL_WIDTH];
                end
            end else if (in_tag == MATRIX_TAG && in_addr == 'd0) begin
                matrix_control_out <= in_data;
            end // No other writable peripheral
        end
    end


    // Sole driver of out_rd_valid/out_rd_data.
    always_ff @(posedge clk) begin
        out_rd_valid <= 1'b0;
        if (in_valid && !in_wr_en) begin
            if (in_tag == MATRIX_TAG) begin
                if(in_addr == 'd0) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_status_in;
                end else if(in_addr == 'd1) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_result_in;
                end
            end
        end
    end

endmodule

// Decode SPI commands to downstream
`include "fpga_types.sv"

module register_model 
#(
    parameter PIXEL_WIDTH = 8,
    parameter PIXEL_PER_WRITE = 2
)
(
    input clk,

    // Packet inputs
    input in_valid,
    input in_wr_en,
    input [`TAG_WIDTH-1:0] in_tag,
    input [`DATA_WIDTH-1:0] in_data,
    input [`ADDR_WIDTH-1:0] in_addr,

    // MULT CONTROL
    output reg pixel_write_enable,
    output reg [PIXEL_PER_WRITE-1:0][PIXEL_WIDTH-1:0] pixel_write_data,
    output reg [PIXELS_PER_WRITE-1:0][`ADDR_WIDTH-1:0] pixel_write_address,

    output reg [15:0] matrix_control_out,
    input [15:0] matrix_result_in,
    input [15:0] matrix_status_in,

    // Read data output to fifo
    output reg out_rd_valid,
    output reg [`DATA_WIDTH-1:0] out_rd_data,
);

    always_ff @(posedge clk) begin
        pixel_write_enable <= 1'b0;
        matrix_control_out <= 1'b0;
        
        if(in_valid && in_wr_en) begin
            if(in_tag == `PIXEL_TAG) begin
                pixel_write_enable <= 1'b1;
                for (int i = 0; i < PIXEL_PER_WRITE; i++) begin
                    pixel_write_address[i] <= in_addr + i;
                    pixel_write_data[i] <= in_data[i*PIXEL_WIDTH +: PIXEL_WIDTH];
                end
            end else if (in_tag == `MATRIX_TAG && in_addr == `ADDR_WIDTH'd0) begin
                matrix_control_out <= in_data;
            end // No other writable peripheral
        end
    end


    // Sole driver of out_rd_valid/out_rd_data.
    always_ff @(posedge clk) begin
        out_rd_valid <= 1'b0;
        if (in_valid && !in_wr_en) begin
            if (peripheral_tag == `MATRIX_TAG) begin
                if(in_addr == `ADDR_WIDTH'd0) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_control;
                end else if(in_addr == `ADDR_WIDTH'd1) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_result;
                end
            end
        end
    end

endmodule
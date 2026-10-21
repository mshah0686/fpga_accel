module top 
import fpga_params::*;
(
    input  fpga_100mhz_clk,       // Main Clock

    // SPI
    input spi_clk, // clk
    input spi_pico, // PICO data
    input spi_cs, // cs
    output spi_poci // POCI data
); 

    // REGISTER_COMMANDS
    wire ral_req_valid;
    wire ral_req_wr_en;
    wire [TAG_WIDTH-1:0] ral_req_tag;
    wire [ADDR_WIDTH-1:0] ral_req_addr;
    wire [DATA_WIDTH-1:0] ral_req_data;

    wire ral_pixel_write_enable;
    wire [1:0][7:0] ral_pixel_write_data;
    wire [9:0] ral_pixel_write_address;

    wire [15:0] matrix_control;
    wire [15:0] matrix_status;
    wire [15:0] matrix_result;
    
    // RAL READ DATA -> SPI TX FIFO (write side; read side lives in spi_top)
    wire [DATA_WIDTH-1:0] rd_data_fifo_wr_data;
    wire rd_data_fifo_wr_en;

    // SPI TOP: RX + CDC + decode -> RAL request bus, and RAL read data -> TX
    spi_top spi_top_u (
        .clk(fpga_100mhz_clk),

        // SPI physical interface
        .spi_sck(spi_clk),
        .spi_pico(spi_pico),
        .spi_cs(spi_cs),
        .spi_poci(spi_poci),

        // Decoded packet -> RAL request bus
        .ral_req_valid(ral_req_valid),
        .ral_req_wr_en(ral_req_wr_en),
        .ral_req_tag(ral_req_tag),
        .ral_req_addr(ral_req_addr),
        .ral_req_data(ral_req_data),

        // RAL read data -> TX FIFO
        .rd_fifo_wr_en(rd_data_fifo_wr_en),
        .rd_fifo_wr_data(rd_data_fifo_wr_data)
    );

    // REGISTER MODEL: decode packet into peripheral control/read strobes
    register_model register_model_u (
        .clk(fpga_100mhz_clk),

        // Packet inputs
        .in_valid(ral_req_valid),
        .in_wr_en(ral_req_wr_en),
        .in_tag(ral_req_tag),
        .in_data(ral_req_data),
        .in_addr(ral_req_addr),

        .pixel_write_enable(ral_pixel_write_enable),
        .pixel_write_data(ral_pixel_write_data),
        .pixel_write_address(ral_pixel_write_address),

        // MATRIX MULT interface
        .matrix_control_out(matrix_control),
        .matrix_result_in(matrix_result),
        .matrix_status_in(matrix_status),

        // Read data output to fifo
        .out_rd_valid(rd_data_fifo_wr_en),
        .out_rd_data(rd_data_fifo_wr_data)
    );

    // MATRIX MULT (2x2) controlled from SPI via the register model.
    // Widths match the register model: 16-bit operands, 32-bit result.
    pipe_top #(
        .REG_WIDTH(16)
    ) matrix_pipe_top_u (
        .clk               (fpga_100mhz_clk),

        .matrix_control_in (matrix_control),
        .matrix_status_out(matrix_status),
        .predicted_result_out(matrix_result),

        .pixel_wr_en(ral_pixel_write_enable),
        .pixel_wr_data(ral_pixel_write_data),
        .pixel_wr_address(ral_pixel_write_address)
    );

endmodule
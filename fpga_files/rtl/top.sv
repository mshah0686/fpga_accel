`include "fpga_types.sv"

module top (
    input  i_clk,       // Main Clock

    // UART
    input  i_UART_RX,   // UART RX Data
    output o_UART_TX,   // UART TX Data

    // Seven segment #1
    output o_Segment1_A,
    output o_Segment1_B,
    output o_Segment1_C,
    output o_Segment1_D,
    output o_Segment1_E,
    output o_Segment1_F,
    output o_Segment1_G,

    // Seven segment #2
    output o_Segment2_A,
    output o_Segment2_B,
    output o_Segment2_C,
    output o_Segment2_D,
    output o_Segment2_E,
    output o_Segment2_F,
    output o_Segment2_G,

    // SPI
    input io_PMOD_1, // clk
    input io_PMOD_2, // PICO data
    input io_PMOD_3, // cs
    output io_PMOD_4, // POCI data

    // DBG
    output io_PMOD_7,
    output io_PMOD_8,
    output io_PMOD_9,
    output io_PMOD_10,

    // LED
    output o_LED_1,
    output o_LED_2,
    output o_LED_3,
    output o_LED_4


); 
    // REGISTER_COMMANDS
    wire ral_req_valid;
    wire ral_req_wr_en;
    wire [`TAG_WIDTH-1:0] ral_req_tag;
    wire [`ADDR_WIDTH-1:0] ral_req_addr;
    wire [`DATA_WIDTH-1:0] ral_req_data;

    wire ral_pixel_write_enable;
    wire [1:0][7:0] pixel_write_data,
    wire [1:0][`ADDR_WIDTH-1:0] pixel_write_address,

    wire [15:0] matrix_control;
    wire [15:0] matrix_status;
    wire [15:0] matrix_result;
    
    // RAL READ DATA -> SPI TX FIFO (write side; read side lives in spi_top)
    wire [`DATA_WIDTH-1:0] rd_data_fifo_wr_data;
    wire rd_data_fifo_wr_en;

    // SPI TOP: RX + CDC + decode -> RAL request bus, and RAL read data -> TX
    spi_top spi_top_u (
        .clk(i_clk),

        // SPI physical interface
        .spi_sck(io_PMOD_1),
        .spi_pico(io_PMOD_2),
        .spi_cs(io_PMOD_3),
        .spi_poci(io_PMOD_4),

        // Decoded packet -> RAL request bus
        .ral_req_valid(ral_req_valid),
        .ral_req_wr_en(ral_req_wr_en),
        .ral_req_tag(ral_req_tag),
        .ral_req_addr(ral_req_addr),
        .ral_req_data(ral_req_data),

        // RAL read data -> TX FIFO
        .rd_fifo_wr_en(rd_data_fifo_wr_en),
        .rd_fifo_wr_data(rd_data_fifo_wr_data),

        // DBG
        .dbg(dbg_io)
    );

    wire ral_pixel_write_enable;
    wire [1:0][7:0] ral_pixel_write_data;
    wire [9:0] ral_pixel_write_address;

    // REGISTER MODEL: decode packet into peripheral control/read strobes
    register_model register_model_u (
        .clk(i_clk),

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
        .clk               (i_clk),

        .matrix_control_in (matrix_control),
        .matrix_status_out(matrix_status),
        .predicted_result_out(matrix_result),

        .pixel_wr_en(ral_pixel_write_enable),
        .pixel_wr_data(ral_pixel_write_data),
        .pixel_wr_address(ral_pixel_write_address)
    );

    assign {io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10} = dbg_io;
    assign {o_LED_1, o_LED_2, o_LED_3, o_LED_4} = dbg_led_io;

endmodule
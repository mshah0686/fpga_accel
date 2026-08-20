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
    wire [`ADDR_WIDTH-1:0] ral_req_addr;
    wire [`DATA_WIDTH-1:0] ral_req_data;

    // TIMER
    wire timer_ctrl_clear, timer_ctrl_stop, timer_ctrl_start, timer_ctrl_en;
    wire [7:0] timer_data_count;
    wire timer_data_en;
    wire [7:0] timer_data_decimal;

    // RAL READ DATA -> SPI TX FIFO (write side; read side lives in spi_top)
    wire [`DATA_WIDTH-1:0] rd_data_fifo_wr_data;
    wire rd_data_fifo_wr_en;

    // MATRIX MULT <-> REGISTER MODEL
    wire [1:0][1:0][7:0] mat_a;              // operands (RAL -> mult)
    wire [1:0][1:0][7:0] mat_b;
    wire [15:0]           mat_control_write;  // control reg (RAL -> mult)
    wire [15:0]           mat_control_status; // status (mult -> RAL, bit0 = idle)
    wire [1:0][1:0][15:0] mat_result;         // result (mult -> RAL)

    // Debug
    wire[3:0] dbg_io;
    wire[3:0] dbg_led_io;

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
        .ral_req_addr(ral_req_addr),
        .ral_req_data(ral_req_data),

        // RAL read data -> TX FIFO
        .rd_fifo_wr_en(rd_data_fifo_wr_en),
        .rd_fifo_wr_data(rd_data_fifo_wr_data),

        // DBG
        .dbg(dbg_io)
    );

    // REGISTER MODEL: decode packet into peripheral control/read strobes
    register_model #(
        .MATRIX_D_WIDTH(8),
        .MATRIX_ACC_WIDTH(16)
    ) register_model_u (
        .clk(i_clk),

        // Packet inputs
        .in_valid(ral_req_valid),
        .in_wr_en(ral_req_wr_en),
        .in_data(ral_req_data),
        .in_addr(ral_req_addr),

        // MATRIX MULT interface
        .a_matrix(mat_a),
        .b_matrix(mat_b),
        .matrix_control_write(mat_control_write),
        .matrix_result(mat_result),
        .matrix_control(mat_control_status),

        // Read data output to fifo
        .out_rd_valid(rd_data_fifo_wr_en),
        .out_rd_data(rd_data_fifo_wr_data),

        // DBG
        .dbg()
    );

    // MATRIX MULT (2x2) controlled from SPI via the register model.
    // Widths match the register model: 16-bit operands, 32-bit result.
    matrix_mult_top #(
        .D_WIDTH   (8),
        .ACC_WIDTH (16),
        .CTRL_WIDTH(16)
    ) matrix_mult_top_u (
        .clk               (i_clk),
        .matrix_control_in (mat_control_write),
        .matrix_control_out(mat_control_status),
        .a                 (mat_a),
        .b                 (mat_b),
        .c                 (mat_result),
        .dbg()
    );

    assign {io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10} = dbg_io;
    assign {o_LED_1, o_LED_2, o_LED_3, o_LED_4} = dbg_led_io;

endmodule
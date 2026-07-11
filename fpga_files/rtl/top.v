//`define DBG_SPI 0
//`define DBG_FIFO_READER
`define DBG_SPI

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
    input io_PMOD_2, // data
    input io_PMOD_3, // cs


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
    parameter SPI_DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 4;

    // SPI PERIPHERAL
    wire [SPI_DATA_WIDTH-1:0] spi_peripheral_out_data;
    wire spi_peripheral_out_valid;

    // SPI SYNC
    wire sync_data_valid;
    wire downstream_ready;
    wire[SPI_DATA_WIDTH-1:0] sync_data;

    // Downstream
    wire uart_ready;

    assign downstream_ready = uart_ready;

    // SPI
    spi_peripheral #(.DATA_WIDTH(SPI_DATA_WIDTH)) 
    spi_slave (
        .spi_clk(io_PMOD_1),
        .spi_data(io_PMOD_2),
        .spi_cs(io_PMOD_3),

        .data_out(spi_peripheral_out_data),
        .data_valid_flag(spi_peripheral_out_valid),
        .pwd_debug({io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10}),
`ifdef DBG_SPI
        .led_dbg ({o_LED_4, o_LED_3, o_LED_2, o_LED_1})
`else
        .led_dbg()
`endif
    );

    spi_rx_sync #(.DATA_WIDTH(SPI_DATA_WIDTH))
    spi_rx_u (
        .system_clk(i_clk),
        .data_out(sync_data),
        .data_valid(sync_data_valid),
        .system_ready(downstream_ready),

        .spi_data_in(spi_peripheral_out_data),
        .spi_data_valid(spi_peripheral_out_valid),

        .led_dbg()
    );

    // UART
    UART_TX uart_tx (
        .clk(i_clk),

        .valid(sync_data_valid),
        .data(sync_data),

        .uart_out(o_UART_TX),
        .ready(uart_ready)
    );

    segment_display DISPLAY_1
    (   
        .clk(i_clk),
        .valid(sync_data_valid),
        .count(sync_data[7:4]),
        .A(o_Segment1_A),
        .B(o_Segment1_B),
        .C(o_Segment1_C),
        .D(o_Segment1_D),
        .E(o_Segment1_E),
        .F(o_Segment1_F),
        .G(o_Segment1_G)
    );

    segment_display DISPLAY_2
    (
        .clk(i_clk),
        .valid(sync_data_valid),
        .count(sync_data[3:0]),
        .A(o_Segment2_A),
        .B(o_Segment2_B),
        .C(o_Segment2_C),
        .D(o_Segment2_D),
        .E(o_Segment2_E),
        .F(o_Segment2_F),
        .G(o_Segment2_G)
    );

endmodule
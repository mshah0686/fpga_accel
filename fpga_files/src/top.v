//`define DBG_SPI 0
//`define DBG_FIFO_READER
`define DBG_ASYNC_FIFO_WRITE

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

    // LED
    output o_LED_1,
    output o_LED_2,
    output o_LED_3,
    output o_LED_4


); 
    parameter SPI_DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 4;

    wire [SPI_DATA_WIDTH-1:0] spi_2_fifo_data;
    wire spi_2_fifo_valid;

    // Fifo 2 Reader
    wire [SPI_DATA_WIDTH-1:0] spi_fifo_read_data;
    wire spi_fifo_read_en;
    wire spi_fifo_empty;

    // Downstream
    wire uart_ready;
    wire read_valid;
    wire [SPI_DATA_WIDTH-1:0] read_data;

    // SPI
    spi_peripheral #(.DATA_WIDTH(SPI_DATA_WIDTH)) 
    spi_slave (
        .spi_clk(io_PMOD_1),
        .spi_data(io_PMOD_2),
        .spi_cs(io_PMOD_3),

        .data_out(spi_2_fifo_data),
        .data_valid(spi_2_fifo_valid),
`ifdef DBG_SPI
        .led_dbg ({o_LED_4, o_LED_3, o_LED_2, o_LED_1})
`else
        .led_dbg()
`endif
    );

    // ASYNC FIFO
    // Cross CDC here from write -> read
    async_fifo #(.DEPTH(FIFO_DEPTH), .DATA_WIDTH(SPI_DATA_WIDTH))
    spi_fifo (
        .w_en(spi_2_fifo_valid),
        .w_data(spi_2_fifo_data),
        .w_clk(io_PMOD_1), // SPI clock domain
        .fifo_full(), // No write back to SPI for now

        .r_en(spi_fifo_read_en),
        .r_data(spi_fifo_read_data),
        .r_clk(i_clk), // FPGA clock domain
        .fifo_empty(spi_fifo_empty),
`ifdef DBG_ASYNC_FIFO_WRITE
        .led_dbg_write ({o_LED_4, o_LED_3, o_LED_2, o_LED_1}),
        .led_dbg_read()
`elsif DBG_ASYNC_FIFO_READ
        .led_dbg_write(),
        .led_dbg_read({o_LED_4, o_LED_3, o_LED_2, o_LED_1})
`else
        .led_dbg_write(),
        .led_dbg_read()
`endif
    );

    // FIFO READER
    fifo_reader #(.DATA_WIDTH(SPI_DATA_WIDTH)) 
    fifo_reader_u (
        .clk(i_clk),

        // FIFO READ
        .fifo_empty(spi_fifo_empty),
        .r_data(spi_fifo_read_data),
        .r_en(spi_fifo_read_en),

        // READY
        .downstream_ready(uart_ready),

        // Data output
        .data_valid(read_valid),
        .data(read_data),
`ifdef DBG_FIFO_READER
        .led_dbg ({o_LED_4, o_LED_3, o_LED_2, o_LED_1})
`else
        .led_dbg()
`endif
    );

    // UART
    UART_TX uart_tx (
        .clk(i_clk),

        .valid(read_valid),
        .data(read_data),

        .uart_out(o_UART_TX),
        .ready(uart_ready)
    );

    segment_display DISPLAY_1
    (   
        .clk(i_clk),
        .valid(read_valid),
        .count(read_data[7:4]),
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
        .valid(read_valid),
        .count(read_data[3:0]),
        .A(o_Segment2_A),
        .B(o_Segment2_B),
        .C(o_Segment2_C),
        .D(o_Segment2_D),
        .E(o_Segment2_E),
        .F(o_Segment2_F),
        .G(o_Segment2_G)
    );

endmodule
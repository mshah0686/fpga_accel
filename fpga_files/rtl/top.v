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
    parameter SPI_DATA_WIDTH = 32; // 4 bytes now
    parameter FIFO_DEPTH = 4;

    // SPI PERIPHERAL
    wire [SPI_DATA_WIDTH-1:0] spi_peripheral_out_data;
    wire spi_peripheral_out_valid;

    // SPI SYNC
    wire sync_valid_out;
    wire downstream_ready;
    wire[SPI_DATA_WIDTH-1:0] sync_data_out;

    // Packet decoder
    wire timer_clear;
    wire timer_start;
    wire timer_stop;

    // Timer
    wire [7:0] timer_count;
    wire [7:0] decimal_timer_count;

    // Debug
    wire[3:0] dbg_io;
    wire[3:0] dbg_led_io;

    // SPI
    spi_peripheral #(.DATA_WIDTH(SPI_DATA_WIDTH))
    spi_slave (
        // INPUT
        .spi_clk(io_PMOD_1),
        .spi_data(io_PMOD_2),
        .spi_cs(io_PMOD_3),
        
        // OUTPUT
        .data_out(spi_peripheral_out_data),
        .data_valid_flag(spi_peripheral_out_valid),

        // DBG
        .pwd_debug(),
        .led_dbg()
    );

    // SYNC SPI -> SYSTEM CLOCK
    spi_rx_sync #(.DATA_WIDTH(SPI_DATA_WIDTH))
    spi_rx_u (
        .system_clk(i_clk),
        // Outputs
        .data_out(sync_data_out),
        .data_valid(sync_valid_out),
        .system_ready(1'b1),  // FIXME::TIED TO 1 for now since no downstream has actual valid

        // Inputs
        .spi_data_in(spi_peripheral_out_data),
        .spi_data_valid(spi_peripheral_out_valid),
        
        // DBG
        .dbg()
    );

    // DECODE PACKET FROM SPI
    packet_decoder packet_decoder_u (
        .clk(i_clk),

        // INPUT
        .packet_valid(sync_valid_out),
        .packet_data(sync_data_out),

        // OUTPUT -> TIMER
        .timer_clear(timer_clear),
        .timer_start(timer_start),
        .timer_stop(timer_stop),

        // DEBUG
        .dbg()
    );

    // TIMER MODULE controlled from SPI
    simple_timer timer_u (
        .clk(i_clk),

        // INPUT
        .start(timer_start),
        .clear(timer_clear),
        .stop(timer_stop),
        
        // OUTPUT -> DISPLAY
        .count(timer_count),
        .tens_place(decimal_timer_count[7:4]),
        .ones_place(decimal_timer_count[3:0]),

        // DBG
        .dbg(dbg_io)
    );

    // DISPLAY TIMER
    segment_display DISPLAY_1
    (
        .clk(i_clk),

        // INPUT
        //.valid(1'b1), // ALWAYS VALID
        .count(decimal_timer_count[7:4]),

        // OUTPUT
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

        // INPUT
        //.valid(1'b1), // ALWAYS VALID
        .count(decimal_timer_count[3:0]),

        // OUTPUT
        .A(o_Segment2_A),
        .B(o_Segment2_B),
        .C(o_Segment2_C),
        .D(o_Segment2_D),
        .E(o_Segment2_E),
        .F(o_Segment2_F),
        .G(o_Segment2_G)
    );

    assign {io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10} = dbg_io;

    assign dbg_led_io = {timer_count[7] | timer_count[6],
                          timer_count[5] | timer_count[4],
                          timer_count[3] | timer_count[2],
                          timer_count[1] | timer_count[0]};

    assign {o_LED_1, o_LED_2, o_LED_3, o_LED_4} = dbg_led_io;

endmodule
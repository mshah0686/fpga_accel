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
    // SPI PERIPHERAL
    wire [`TXN_WIDTH-1:0] spi_rx_data;
    wire spi_rx_valid;

    // SPI SYNC OUT
    wire spi_rx_synced_valid;
    wire[`TXN_WIDTH-1:0] spi_rx_synced_data;

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

    // OUTPUT DATA FIFO
    wire [`DATA_WIDTH-1:0] rd_data_fifo_rd_data;
    wire [`DATA_WIDTH-1:0] rd_data_fifo_wr_data;
    wire rd_data_fifo_empty;
    wire rd_data_fifo_rd_en;
    wire rd_data_fifo_wr_en;


    // Debug
    wire[3:0] dbg_io;
    wire[3:0] dbg_led_io;

    // SPI
    spi_rx #(.DATA_WIDTH(`TXN_WIDTH))
    spi_rx_u (
        // INPUT
        .spi_clk(io_PMOD_1),
        .spi_pico(io_PMOD_2),
        .spi_cs(io_PMOD_3),
        
        // OUTPUT
        .data_out(spi_rx_data),
        .data_valid_flag(spi_rx_valid),

        // DBG
        .pwd_debug(),
        .led_dbg()
    );

    // SYNC SPI -> SYSTEM CLOCK
    spi_rx_sync #(.DATA_WIDTH(`TXN_WIDTH))
    spi_rx_sync_u (
        .system_clk(i_clk),

        // Inputs
        .spi_data_in(spi_rx_data),
        .spi_data_valid(spi_rx_valid),

        // Outputs
        .data_out(spi_rx_synced_data),
        .data_valid(spi_rx_synced_valid),
        .system_ready(1'b1),
        
        // DBG
        .dbg()
    );

    // DECODE PACKET FROM SPI
    packet_decoder packet_decoder_u (
        .clk(i_clk),

        // INPUT
        .packet_valid(spi_rx_synced_valid),
        .packet_data(spi_rx_synced_data),

        // OUTPUT RAL CONTROL
        .out_valid(ral_req_valid),
        .out_wr_en(ral_req_wr_en),
        .out_addr(ral_req_addr),
        .out_data(ral_req_data)
    );

    // REGISTER MODEL: decode packet into peripheral control/read strobes
    register_model register_model_u (
        .clk(i_clk),

        // Packet inputs
        .in_valid(ral_req_valid),
        .in_wr_en(ral_req_wr_en),
        .in_data(ral_req_data),
        .in_addr(ral_req_addr),

        // Peripheral Controls -> TIMER
        .out_timer_clear(timer_ctrl_clear),
        .out_timer_start(timer_ctrl_start),
        .out_timer_stop(timer_ctrl_stop),

        // Peripheral input data
        .in_timer_en(timer_data_en),
        .in_timer_count(timer_data_count),

        // Read data output to fifo
        .out_rd_valid(rd_data_fifo_wr_en),
        .out_rd_data(rd_data_fifo_wr_data),

        // DBG
        .dbg()
    );

    // TIMER MODULE controlled from SPI
    simple_timer timer_u (
        .clk(i_clk),

        // INPUT
        .start(timer_ctrl_start),
        .clear(timer_ctrl_clear),
        .stop(timer_ctrl_stop),
        
        // OUTPUT -> DISPLAY
        .timer_en(timer_data_en),
        .count(timer_data_count),
        .tens_place(timer_data_decimal[7:4]),
        .ones_place(timer_data_decimal[3:0]),

        // DBG
        .dbg()
    );

    // DISPLAY TIMER
    segment_display DISPLAY_1
    (
        .clk(i_clk),

        // INPUT
        //.valid(1'b1), // ALWAYS VALID
        .count(timer_data_decimal[7:4]),

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
        .count(timer_data_decimal[3:0]),

        // OUTPUT
        .A(o_Segment2_A),
        .B(o_Segment2_B),
        .C(o_Segment2_C),
        .D(o_Segment2_D),
        .E(o_Segment2_E),
        .F(o_Segment2_F),
        .G(o_Segment2_G)
    );

    async_fifo #(
        .DEPTH(2), 
        .DATA_WIDTH(`DATA_WIDTH)
    ) rd_out_fifo_u (
        .w_en(rd_data_fifo_wr_en),
        .w_data(rd_data_fifo_wr_data),
        .w_clk(i_clk),
        .fifo_full(),

        .r_en(rd_data_fifo_rd_en),
        .r_data(rd_data_fifo_rd_data),
        .r_clk(~io_PMOD_1),
        .fifo_empty(rd_data_fifo_empty),

        .led_dbg_read(),
        .led_dbg_write()
    );

    //assign dbg_io = {rd_data_fifo_empty, rd_data_fifo_rd_en, rd_data_fifo_wr_en, ~io_PMOD_1};

    spi_tx #(
        .TXN_WIDTH(`TXN_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) spi_tx_u (
        .spi_clk(io_PMOD_1),
        .spi_poci(io_PMOD_4),
        .spi_cs(io_PMOD_3),

        // FIFO connection
        .fifo_read_data_in(rd_data_fifo_rd_data),
        .fifo_empty_in(rd_data_fifo_empty),
        .r_en_out(rd_data_fifo_rd_en),

        .dbg(dbg_io)
    );

    assign {io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10} = dbg_io;
    assign {o_LED_1, o_LED_2, o_LED_3, o_LED_4} = dbg_led_io;

endmodule
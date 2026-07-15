`timescale 1ns/1ps
module tb_spi_timer_control_top;

    // SPI transaction width matches top's SPI_DATA_WIDTH (CMD_WIDTH + ADDR_WIDTH + DATA_WIDTH)
    parameter SPI_DATA_WIDTH = 32;

    // Master fast base clock definition (e.g., 50MHz = 20ns period)
    parameter FAST_CLK_PERIOD = 20;

    // How many fast clock cycles equal ONE slow system clock cycle?
    localparam int FAST_CYCLES_PER_SYSTEM_CLK = 5;

    // DUT Inputs
    reg i_clk;
    reg i_UART_RX;
    reg io_PMOD_1;   // SPI clk
    reg io_PMOD_2;   // SPI data
    reg io_PMOD_3;   // SPI cs

    // DUT Outputs
    wire o_UART_TX;

    wire o_Segment1_A, o_Segment1_B, o_Segment1_C, o_Segment1_D;
    wire o_Segment1_E, o_Segment1_F, o_Segment1_G;

    wire o_Segment2_A, o_Segment2_B, o_Segment2_C, o_Segment2_D;
    wire o_Segment2_E, o_Segment2_F, o_Segment2_G;

    wire io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10;

    wire o_LED_1, o_LED_2, o_LED_3, o_LED_4;

    // Internal Master Base Clock (Verilator's evaluation engine heart)
    reg fast_base_clk;

    // Instantiate DUT
    top uut (
        .i_clk(i_clk),

        .i_UART_RX(i_UART_RX),
        .o_UART_TX(o_UART_TX),

        .o_Segment1_A(o_Segment1_A),
        .o_Segment1_B(o_Segment1_B),
        .o_Segment1_C(o_Segment1_C),
        .o_Segment1_D(o_Segment1_D),
        .o_Segment1_E(o_Segment1_E),
        .o_Segment1_F(o_Segment1_F),
        .o_Segment1_G(o_Segment1_G),

        .o_Segment2_A(o_Segment2_A),
        .o_Segment2_B(o_Segment2_B),
        .o_Segment2_C(o_Segment2_C),
        .o_Segment2_D(o_Segment2_D),
        .o_Segment2_E(o_Segment2_E),
        .o_Segment2_F(o_Segment2_F),
        .o_Segment2_G(o_Segment2_G),

        .io_PMOD_1(io_PMOD_1),
        .io_PMOD_2(io_PMOD_2),
        .io_PMOD_3(io_PMOD_3),

        .io_PMOD_7(io_PMOD_7),
        .io_PMOD_8(io_PMOD_8),
        .io_PMOD_9(io_PMOD_9),
        .io_PMOD_10(io_PMOD_10),

        .o_LED_1(o_LED_1),
        .o_LED_2(o_LED_2),
        .o_LED_3(o_LED_3),
        .o_LED_4(o_LED_4)
    );

    // 1. Generate the Master FAST Base Clock
    initial begin
        fast_base_clk = 0;
        forever #(FAST_CLK_PERIOD/2) fast_base_clk = ~fast_base_clk;
    end

    // 2. Generate the SLOW system clock synchronously from the fast clock
    initial begin
        i_clk = 0;
        forever begin
            repeat(FAST_CYCLES_PER_SYSTEM_CLK) @(negedge fast_base_clk);
            i_clk = ~i_clk;
        end
    end

    // 3. Main Stimulus Sequence - SPI commands only, no checking
    initial begin
        io_PMOD_1 <= 1'b0;
        io_PMOD_2 <= 1'b0;
        io_PMOD_3 <= 1'b1;
        i_UART_RX <= 1'b1;

        repeat(5) @(negedge i_clk);

        // Scenario 1: Start the timer
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_START});
        for(int i = 0; i < 10; i++) begin
            repeat(250) @(negedge i_clk);
        end

        // Scenario 2: Stop the timer
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_STOP});
        repeat(30) @(negedge i_clk);

        // Scenario 3: Restart after a stop
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_START});
        repeat(20) @(negedge i_clk);

        // Scenario 4: Clear while running
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_CLEAR});
        repeat(20) @(negedge i_clk);

        // Scenario 5: Back-to-back start/stop with minimal gap (stresses CDC + edge detect)
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_START});
        repeat(2) @(negedge fast_base_clk);
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_STOP});
        repeat(20) @(negedge i_clk);

        // Scenario 6: NOP command should not touch the timer
        send_spi_word({CMD_NOP, TIMER_ADDR, 16'h0000});
        repeat(20) @(negedge i_clk);

        // Scenario 8: Clean start/stop to close out the run
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_START});
        repeat(20) @(negedge i_clk);
        send_spi_word({CMD_WRITE, TIMER_ADDR, TIMER_STOP});

        repeat(50) @(negedge i_clk);
        $display("[%0t] All stimulus sent.", $time);
        $finish;
    end

    // 4. Fast Driver Task: shifts a full SPI_DATA_WIDTH word out MSB-first
    task send_spi_word(input [SPI_DATA_WIDTH-1:0] data);
        reg [SPI_DATA_WIDTH-1:0] temp_data;
        integer i;
        begin
            temp_data = data;
            $display("[%0t] Sending SPI word: 0x%0h", $time, temp_data);

            io_PMOD_3 <= 1'b0;

            for (i = 0; i < SPI_DATA_WIDTH; i = i + 1) begin
                io_PMOD_2 <= temp_data[SPI_DATA_WIDTH-1];
                temp_data = temp_data << 1;

                @(negedge fast_base_clk);
                io_PMOD_1 <= 1'b1;

                @(negedge fast_base_clk);
                io_PMOD_1 <= 1'b0;
            end

            @(negedge fast_base_clk);
            io_PMOD_3 <= 1'b1;
            io_PMOD_1 <= 1'b0;
        end
    endtask

endmodule

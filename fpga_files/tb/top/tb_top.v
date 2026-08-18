`timescale 1ns/1ps
`include "fpga_types.sv"
module tb_top;

    // SPI transaction width (CMD_WIDTH + ADDR_WIDTH + DATA_WIDTH)
    parameter SPI_TXN_WIDTH = 32;
    parameter SPI_COMMAND_WIDTH = 8;
    parameter SPI_ADDR_WIDTH = 8;
    parameter SPI_DATA_WIDTH = 16;

    // Master fast base clock definition (e.g., 50MHz = 20ns period)
    parameter FAST_CLK_PERIOD = 20;

    // How many fast clock cycles equal ONE slow system clock cycle?
    localparam int FAST_CYCLES_PER_SYSTEM_CLK = 10;

    // DUT driven inputs
    reg i_clk;
    reg i_UART_RX;
    reg io_PMOD_1;   // SPI clk
    reg io_PMOD_2;   // SPI PICO data
    reg io_PMOD_3;   // SPI cs

    // DUT outputs
    wire io_PMOD_4;  // SPI POCI data (driven by DUT)
    wire o_UART_TX;

    wire o_Segment1_A, o_Segment1_B, o_Segment1_C, o_Segment1_D;
    wire o_Segment1_E, o_Segment1_F, o_Segment1_G;

    wire o_Segment2_A, o_Segment2_B, o_Segment2_C, o_Segment2_D;
    wire o_Segment2_E, o_Segment2_F, o_Segment2_G;

    wire io_PMOD_7, io_PMOD_8, io_PMOD_9, io_PMOD_10;

    wire o_LED_1, o_LED_2, o_LED_3, o_LED_4;

    // Internal Master Base Clock (Verilator's evaluation engine heart)
    reg fast_base_clk;

    integer k;

    // Instantiate DUT
    top uut (
        .i_clk(fast_base_clk),

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
        .io_PMOD_4(io_PMOD_4),

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

    // 3a. SPI TX read-back monitor thread (runs in parallel with the stimulus)
    //     - Chip select (io_PMOD_3, active low) starts a capture
    //     - Sample POCI (io_PMOD_4) on each posedge of the slow SPI clock
    //       (io_PMOD_1) and shift it MSB-first into a 32-bit register
    //     - On CS release the transaction is done: if the upper 16 bits are
    //       all zero, print the last 16 bits (the actual read data)
    reg [SPI_TXN_WIDTH-1:0] tx_capture;

    initial begin
        forever begin
            // Wait for chip select to assert (active low) -> start capture
            @(negedge io_PMOD_3);
            tx_capture = '0;

            // Shift POCI in on every SPI clock posedge until CS releases
            while (io_PMOD_3 == 1'b0) begin
                @(posedge io_PMOD_1 or posedge io_PMOD_3);
                if (io_PMOD_3 == 1'b0)
                    tx_capture = {tx_capture[SPI_TXN_WIDTH-2:0], io_PMOD_4};
            end

            // Transaction complete: print last 16 bits if the first 16 are all 0
            if (tx_capture[SPI_TXN_WIDTH-1 -: SPI_DATA_WIDTH] == '0)
                $display("[%0t] SPI TX read data = 0x%04h  (full=0x%08h)",
                         $time, tx_capture[SPI_DATA_WIDTH-1:0], tx_capture);
        end
    end

    // 3. Setup only - no stimulus yet
    initial begin
        io_PMOD_1 <= 1'b0;
        io_PMOD_2 <= 1'b0;
        io_PMOD_3 <= 1'b1;
        i_UART_RX <= 1'b1;

        repeat(5) @(negedge i_clk);


        for(k = 0; k <3; k++) begin
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(0), .row_idx(0), .col_idx(0)), 16'd1 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(0), .row_idx(0), .col_idx(1)), 16'd2 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(0), .row_idx(1), .col_idx(0)), 16'd3 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(0), .row_idx(1), .col_idx(1)), 16'd4 + SPI_DATA_WIDTH'(k));

            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(1), .row_idx(0), .col_idx(0)), 16'd5 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(1), .row_idx(0), .col_idx(1)), 16'd6 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(1), .row_idx(1), .col_idx(0)), 16'd7 + SPI_DATA_WIDTH'(k));
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(1), .row_idx(1), .col_idx(1)), 16'd8 + SPI_DATA_WIDTH'(k));

            // Execute
            send_spi_word(`CMD_WRITE, get_matrix_addr(.matrix_type(3), .row_idx(0), .col_idx(0)), 16'd1);
            // Read status
            send_spi_word(`CMD_READ, get_matrix_addr(.matrix_type(3), .row_idx(0), .col_idx(0)), 16'd1);
            send_spi_word(`CMD_NOP, 8'd0, 16'd0);

            // Read matrix out results
            send_spi_word(`CMD_READ, get_matrix_addr(.matrix_type(2), .row_idx(0), .col_idx(0)), 16'd0);
            send_spi_word(`CMD_READ, get_matrix_addr(.matrix_type(2), .row_idx(0), .col_idx(1)), 16'd1);
            send_spi_word(`CMD_READ, get_matrix_addr(.matrix_type(2), .row_idx(1), .col_idx(0)), 16'd1);
            send_spi_word(`CMD_READ, get_matrix_addr(.matrix_type(2), .row_idx(1), .col_idx(1)), 16'd1);
            send_spi_word(`CMD_NOP, 8'd0, 16'd0); // One extra read
        end

        repeat(50) @(negedge i_clk);
        $display("[%0t] Testbench setup complete (no stimulus).", $time);
        $finish;
    end

    // 4. Fast Driver Task: shifts a full SPI_DATA_WIDTH word out MSB-first
    task send_spi_word(
        input [SPI_COMMAND_WIDTH-1:0] cmd,
        input [SPI_ADDR_WIDTH-1:0] addr,
        input [SPI_DATA_WIDTH-1:0] data
    );
        reg [SPI_TXN_WIDTH-1:0] temp_data;
        integer i;
        begin
            temp_data = {cmd, addr, data};
            $display("[%0t] Sending SPI word: cmd=0x%0h addr=0x%0h data=0x%0h",
                     $time, cmd, addr, data);

            io_PMOD_3 <= 1'b0;

            for (i = 0; i < SPI_TXN_WIDTH; i = i + 1) begin
                io_PMOD_2 <= temp_data[SPI_TXN_WIDTH-1];
                temp_data = temp_data << 1;

                @(negedge i_clk);
                io_PMOD_1 <= 1'b1;

                @(negedge i_clk);
                io_PMOD_1 <= 1'b0;
            end

            @(negedge i_clk);
            io_PMOD_3 <= 1'b1;
            io_PMOD_1 <= 1'b0;
            @(negedge i_clk);
        end
    endtask

    function bit[7:0] get_matrix_addr(int matrix_type, int row_idx, int col_idx);
        return {matrix_type[1:0], row_idx[0], col_idx[0], 2'b00, 2'b11};
    endfunction


endmodule

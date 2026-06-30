`timescale 1ns/1ps

module tb_spi_peripheral;

    parameter DATA_WIDTH          = 8;
    parameter NUM_TRANSACTIONS    = 10;
    parameter CONTINUOUS_PERCENT  = 70;      // % chance CS stays low
    parameter CLK_PERIOD          = 12.5;    // ns (80 MHz)

    reg                     spi_clk;
    reg                     spi_cs;
    reg                     spi_data;

    wire [DATA_WIDTH-1:0]   spi_data_out;
    wire                    spi_valid;

    reg [DATA_WIDTH-1:0] expected_data;

    integer i;
    integer bitnum;
    integer delay_cycles;

    //------------------------------------------------------------
    // DUT
    //------------------------------------------------------------
    spi_peripheral #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .spi_clk(spi_clk),
        .spi_data(spi_data),
        .spi_cs(spi_cs),

        .data_out(spi_data_out),
        .data_valid(spi_valid)
    );

    //------------------------------------------------------------
    // 80 MHz SPI Clock
    //------------------------------------------------------------
    initial
        spi_clk = 0;

    always #(CLK_PERIOD/2.0)
        spi_clk = ~spi_clk;

    //------------------------------------------------------------
    // Send one DATA_WIDTH-bit SPI transaction (MSB first)
    //------------------------------------------------------------
    task send_transaction;
        input [DATA_WIDTH-1:0] tx_data;
        begin
            for (bitnum = DATA_WIDTH-1; bitnum >= 0; bitnum = bitnum - 1) begin
                spi_data = tx_data[bitnum];
                @(posedge spi_clk);
            end
        end
    endtask

    //------------------------------------------------------------
    // Check received data
    //------------------------------------------------------------
    always @(posedge spi_clk) begin
        if (spi_valid) begin
            if (spi_data_out === expected_data)
                $display("[%0t] PASS  Received: 0x%0h",
                         $time, spi_data_out);
            else
                $display("[%0t] FAIL  Expected: 0x%0h  Received: 0x%0h",
                         $time, expected_data, spi_data_out);
        end
    end

    //------------------------------------------------------------
    // Stimulus
    //------------------------------------------------------------
    initial begin

        spi_cs   = 1'b1;
        spi_data = 1'b0;

        repeat (5)
            @(posedge spi_clk);

        // Begin first transaction
        spi_cs = 1'b0;

        for (i = 0; i < NUM_TRANSACTIONS; i = i + 1) begin

            expected_data = $urandom;

            send_transaction(expected_data);

            // Random idle clocks before next transfer
            delay_cycles = $urandom_range(0,5);
            repeat(delay_cycles)
                @(posedge spi_clk);

            // Randomly decide whether to toggle CS
            if ($urandom_range(0,99) >= CONTINUOUS_PERCENT) begin

                spi_cs = 1'b1;

                // Hold CS high for 1-3 clocks
                repeat($urandom_range(1,3))
                    @(posedge spi_clk);

                spi_cs = 1'b0;
            end

        end

        // End SPI session
        spi_cs = 1'b1;

        repeat(5)
            @(posedge spi_clk);

        $display("------------------------------------");
        $display("Completed %0d SPI transactions.", NUM_TRANSACTIONS);
        $display("------------------------------------");

        $finish;
    end

endmodule
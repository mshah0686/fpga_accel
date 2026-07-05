`timescale 1ns/1ps

module async_fifo_tb;

    localparam DEPTH      = 4;
    localparam DATA_WIDTH = 4;

    //--------------------------------------------
    // DUT signals
    //--------------------------------------------
    logic                     w_clk;
    logic                     r_clk;

    logic                     w_en;
    logic [DATA_WIDTH-1:0]    w_data;
    logic                     fifo_full;

    logic                     r_en;
    logic [DATA_WIDTH-1:0]    r_data;
    logic                     fifo_empty;

    //--------------------------------------------
    // Scoreboard
    //--------------------------------------------
    logic [DATA_WIDTH-1:0] expected_q[$];

    //--------------------------------------------
    // Counters
    //--------------------------------------------
    int unsigned write_count = 0;
    int unsigned read_count  = 0;

    //--------------------------------------------
    // DUT
    //--------------------------------------------
    async_fifo #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .w_clk(w_clk),
        .w_en(w_en),
        .w_data(w_data),
        .fifo_full(fifo_full),

        .r_clk(r_clk),
        .r_en(r_en),
        .r_data(r_data),
        .fifo_empty(fifo_empty)
    );

    //--------------------------------------------
    // Clocks
    //--------------------------------------------

    // 80 MHz write clock (12.5 ns period)
    initial begin
        w_clk = 0;
        forever #6.25 w_clk = ~w_clk;
    end

    // 25 MHz read clock (40 ns period)
    initial begin
        r_clk = 0;
        forever #20 r_clk = ~r_clk;
    end

    //--------------------------------------------
    // Writer Task
    //--------------------------------------------
    task automatic writer();

        int delay_cycles;
        logic [DATA_WIDTH-1:0] rand_data;

        int num_writes = $urandom_range(0,300);

        for(int i = 0; i < num_writes; i ++) begin

            delay_cycles = $urandom_range(0,8);
            repeat(delay_cycles) @(posedge w_clk);

            wait(!fifo_full);

            rand_data = $urandom;

            // Drive before edge
            w_data = rand_data;
            w_en   = 1'b1;

            @(posedge w_clk);

            if (!fifo_full) begin
                expected_q.push_back(rand_data);
                write_count++;
            end

            w_en = 1'b0;

        end

    endtask

    //--------------------------------------------
    // Reader Task
    //--------------------------------------------
    task automatic reader();

        int delay_cycles;
        logic [DATA_WIDTH-1:0] expected_data;

        forever begin

            delay_cycles = $urandom_range(0,12);
            repeat(delay_cycles) @(posedge r_clk);

            wait(!fifo_empty);

            r_en = 1'b1;

            @(posedge r_clk);

            if (!fifo_empty) begin

                expected_data = expected_q.pop_front();
                read_count++;

                if (r_data !== expected_data) begin
                    $error("[%0t] MISMATCH exp=%02h got=%02h",
                            $time, expected_data, r_data);
                    $fatal;
                end
                else begin
                    $display("[%0t] PASS  data=%02h",
                             $time, r_data);
                end

            end

            r_en = 1'b0;

        end

    endtask

    //--------------------------------------------
    // Test control
    //--------------------------------------------
    initial begin

        w_en = 0;
        r_en = 0;

        fork
            writer();
            reader();
        join_any

        wait(expected_q.size() == 0);
        disable fork;

        $display("\n==============================");
        $display("WRITE COUNT : %0d", write_count);
        $display("READ COUNT  : %0d", read_count);
        $display("QUEUE SIZE  : %0d", expected_q.size());

        if (expected_q.size() == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED (DATA LEFT IN FIFO)");

        $display("==============================\n");

        $finish;
    end

endmodule
`timescale 1ns/1ps

module tb_matrix_mult_top;

    parameter PIXEL_WIDTH = 8;
    parameter ACTIVATION_WIDTH = 16;
    parameter ACC_WIDTH  = 32;
    parameter M          = 16;   // rows of A / rows of C
    parameter K          = 784;  // cols of A / rows of B
    parameter N          = 1;    // cols of B / cols of C
    parameter REG_WIDTH  = 16;

    parameter CLK_PERIOD = 10;

    // Golden results, relative to the simulator's working directory
    // (fpga_files/, same convention as the RTL's "weights/..." $readmemh
    // and the C++ harness's "waves/..." VCD path).
    parameter EXPECTED_FILE = "tb/matrix_mult/expected_c.hex";

    // Array drains in M + N + K - 2 cycles; allow generous slack on top so a
    // healthy run never trips the watchdog but a hung FSM still bails out.
    parameter EXEC_CYCLES = M + N + K - 2;
    parameter TIMEOUT     = (EXEC_CYCLES + 300) * CLK_PERIOD;

    // Control register bit map (matrix_control_in / matrix_control_out)
    localparam CTRL_REQ_VALID = 0;   // in:  pulse to kick off one multiply
    localparam STAT_IDLE      = 0;   // out: high when the controller is idle

    // DUT inputs
    reg clk;
    reg [REG_WIDTH-1:0] matrix_control_in;

    // DUT outputs
    wire [REG_WIDTH-1:0] matrix_control_out;
    wire [M-1:0][N-1:0][ACC_WIDTH-1:0] c_out;

    wire idle = matrix_control_out[STAT_IDLE];

    // Precomputed reference product, row-major: expected_c[i*N + j] <-> c[i][j].
    // Flat because $readmemh fills a 1-D unpacked array.
    reg [ACC_WIDTH-1:0] expected_c [0:M*N-1];

    integer errors;
    integer i, j;
    time start_time;

    matrix_mult_top #(
        .A_DATA_WIDTH (ACTIVATION_WIDTH),
        .B_DATA_WIDTH(PIXEL_WIDTH),
        .ACC_WIDTH  (ACC_WIDTH),
        .M          (M),
        .K          (K),
        .N          (N),
        .REG_WIDTH  (REG_WIDTH)
    ) uut (
        .clk                (clk),
        .matrix_control_in  (matrix_control_in),
        .matrix_control_out (matrix_control_out),
        .c                  (c_out)
    );

    // Free-running system clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Watchdog so a hung FSM does not spin forever
    initial begin
        #(TIMEOUT);
        $display("[%0t] TIMEOUT: compute never completed (idle=%0b)", $time, idle);
        $display("[%0t] FAIL: %0dx%0d * %0dx%0d did not finish in %0d cycles",
                 $time, M, K, K, N, EXEC_CYCLES + 300);
        $finish;
    end

    // ------------------------------------------------------------------
    // Stimulus tasks
    // ------------------------------------------------------------------

    // Single-cycle req_valid pulse on the control register.
    task pulse_req;
        begin
            @(negedge clk);
            matrix_control_in[CTRL_REQ_VALID] <= 1'b1;
            @(negedge clk);
            matrix_control_in[CTRL_REQ_VALID] <= 1'b0;
            $display("[%0t] req_valid pulsed.", $time);
        end
    endtask

    // Operand load. The BRAMs self-preload via $readmemh at time 0, so there
    // is nothing to drive here yet - this task is the hook for when
    // matrix_mult_top exposes the bram_wrapper write ports (w_en/w_addr/w_data)
    // so pixel data can be streamed in over SPI instead of baked into a .hex.
    task load_operands;
        begin
            $display("[%0t] Operands come from BRAM $readmemh preload (rtl/weights/*.hex).",
                     $time);
        end
    endtask

    // Pull in the golden results. $readmemh only warns on a missing file and
    // leaves the array X, which would show up as M*N confusing mismatches, so
    // catch that here and say what actually went wrong.
    task load_expected;
        begin
            $readmemh(EXPECTED_FILE, expected_c);
            if (^expected_c[0] === 1'bx) begin
                $display("[%0t] ERROR: could not load golden file '%s'.", $time, EXPECTED_FILE);
                $display("         Generate it with: python3 scripts/gen_matmul_golden.py");
                $display("         The path is relative to the sim working directory,");
                $display("         so run the binary from fpga_files/.");
                $fatal(1, "missing golden data");
            end
            $display("[%0t] Loaded %0d golden values from %s.", $time, M*N, EXPECTED_FILE);
        end
    endtask

    // Compare one result element against its precomputed value
    task check_elem;
        input integer row;
        input integer col;
        input [ACC_WIDTH-1:0] expected;
        begin
            if (c_out[row][col] !== expected) begin
                $display("  MISMATCH c[%2d][%0d] = %0d (0x%07h), expected %0d (0x%07h)",
                         row, col, c_out[row][col], c_out[row][col], expected, expected);
                errors = errors + 1;
            end else begin
                $display("  OK       c[%2d][%0d] = %0d (0x%07h)",
                         row, col, c_out[row][col], c_out[row][col]);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------
    initial begin
        errors            = 0;
        matrix_control_in = {REG_WIDTH{1'b0}};

        load_expected;

        // Let the $readmemh preloads settle before poking the controller.
        repeat (5) @(posedge clk);

        load_operands;

        pulse_req;

        // Controller drops idle while the array is running
        wait (idle == 1'b0);
        start_time = $time;
        $display("[%0t] Compute started (idle deasserted).", $time);

        // ...and raises it again after the SAVE state latches c
        wait (idle == 1'b1);
        $display("[%0t] Compute finished (idle asserted) after %0d cycles (array needs %0d).",
                 $time, ($time - start_time) / CLK_PERIOD, EXEC_CYCLES);
        @(posedge clk);

        // ---------------------------------------------------------------
        // Check C against the golden product
        // ---------------------------------------------------------------
        $display("[%0t] Checking C (%0dx%0d):", $time, M, N);
        for (i = 0; i < M; i = i + 1)
            for (j = 0; j < N; j = j + 1)
                check_elem(i, j, expected_c[i*N + j]);

        if (errors == 0)
            $display("[%0t] PASS: %0dx%0d * %0dx%0d matches %s",
                     $time, M, K, K, N, EXPECTED_FILE);
        else
            $display("[%0t] FAIL: %0d of %0d elements mismatched",
                     $time, errors, M*N);

        repeat (10) @(posedge clk);
        $finish;
    end

endmodule

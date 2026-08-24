`timescale 1ns/1ps

//
// Testbench: one dense neural-net layer, 16x784 * 784x1, static operands.
//
//        A (16x784)              B (784x1)          C (16x1)
//     [ w0,0  ... w0,783 ]      [ px_0   ]        [ act_0  ]
//     [  ...          ... ]  *  [  ...   ]   =    [  ...   ]
//     [ w15,0 ... w15,783]      [ px_783 ]        [ act_15 ]
//
// This maps onto an M x N = 16 x 1 systolic array with a K = 784 deep
// accumulation, so it exercises the long accumulate path rather than a wide
// PE grid. Operands and expected results are preloaded from a generated
// include file (see scripts/gen_matmul_data.py) - no randomization at
// runtime, so every run checks the same known-good product.
//
// One req_valid pulse is issued through matrix_control_in[0]; the result is
// then compared element-by-element against the precomputed values.
//
module tb_matrix_mult_top;

    parameter D_WIDTH   = 8;
    parameter ACC_WIDTH = 26;
    parameter M         = 16;   // rows of A / rows of C
    parameter K         = 784;  // cols of A / rows of B
    parameter N         = 1;    // cols of B / cols of C
    parameter REG_WIDTH = 16;

    parameter CLK_PERIOD = 10;

    // Array drains in M + N + K - 2 cycles; allow generous slack on top so a
    // healthy run never trips the watchdog but a hung FSM still bails out.
    parameter EXEC_CYCLES = M + N + K - 2;
    parameter TIMEOUT     = (EXEC_CYCLES + 300) * CLK_PERIOD;

    // Number of leading elements echoed when previewing an operand
    parameter PREVIEW = 8;

    // DUT inputs
    reg clk;
    reg [REG_WIDTH-1:0] matrix_control_in;
    reg [M-1:0][K-1:0][D_WIDTH-1:0] a;
    reg [K-1:0][N-1:0][D_WIDTH-1:0] b;

    // DUT outputs
    wire [REG_WIDTH-1:0] matrix_control_out;
    wire [M-1:0][N-1:0][ACC_WIDTH-1:0] c_out;

    // Control register bit map
    wire idle = matrix_control_out[0];

    // Precomputed reference product, filled in by the generated include
    reg [ACC_WIDTH-1:0] expected_c [0:M-1][0:N-1];

    integer errors;
    integer i, j;
    time start_time;

    matrix_mult_top #(
        .D_WIDTH   (D_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .M         (M),
        .K         (K),
        .N         (N),
        .REG_WIDTH (REG_WIDTH)
    ) uut (
        .clk                (clk),
        .matrix_control_in  (matrix_control_in),
        .matrix_control_out (matrix_control_out),
        .a                  (a),
        .b                  (b),
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

    // Compare one result element against its precomputed value
    task check_elem;
        input integer row;
        input integer col;
        input [ACC_WIDTH-1:0] expected;
        begin
            if (c_out[row][col] !== expected) begin
                $display("  MISMATCH c[%0d][%0d] = %0d (0x%07h), expected %0d (0x%07h)",
                         row, col, c_out[row][col], c_out[row][col], expected, expected);
                errors = errors + 1;
            end else begin
                $display("  OK       c[%0d][%0d] = %0d (0x%07h)",
                         row, col, c_out[row][col], c_out[row][col]);
            end
        end
    endtask

    initial begin
        errors            = 0;
        matrix_control_in = {REG_WIDTH{1'b0}};

        // ---------------------------------------------------------------
        // Static operands + expected product (generated, do not hand-edit)
        // ---------------------------------------------------------------
        `include "matrix_data.vh"

        repeat (3) @(posedge clk);

        // A and B are far too large to dump in full; show a leading slice of
        // each so the waveform/log can be spot-checked against the generator.
        $display("[%0t] A (%0dx%0d), first %0d of each row:", $time, M, K, PREVIEW);
        for (i = 0; i < M; i = i + 1) begin
            $write("    a[%2d] =", i);
            for (j = 0; j < PREVIEW; j = j + 1) $write(" %02h", a[i][j]);
            $write(" ...\n");
        end

        $display("[%0t] B (%0dx%0d), first %0d elements:", $time, K, N, PREVIEW);
        $write("    b[0..%0d][0] =", PREVIEW - 1);
        for (i = 0; i < PREVIEW; i = i + 1) $write(" %02h", b[i][0]);
        $write(" ...\n");

        // ---------------------------------------------------------------
        // Single req_valid pulse (matrix_control_in[0])
        // ---------------------------------------------------------------
        @(negedge clk);
        matrix_control_in[0] <= 1'b1;
        @(negedge clk);
        matrix_control_in[0] <= 1'b0;
        $display("[%0t] req_valid pulsed.", $time);

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
        // Check C_out against the precomputed product
        // ---------------------------------------------------------------
        $display("[%0t] Checking C (%0dx%0d):", $time, M, N);
        for (i = 0; i < M; i = i + 1)
            for (j = 0; j < N; j = j + 1)
                check_elem(i, j, expected_c[i][j]);

        if (errors == 0)
            $display("[%0t] PASS: %0dx%0d * %0dx%0d result matches expected values",
                     $time, M, K, K, N);
        else
            $display("[%0t] FAIL: %0d of %0d elements mismatched",
                     $time, errors, M*N);

        repeat (10) @(posedge clk);
        $finish;
    end

endmodule

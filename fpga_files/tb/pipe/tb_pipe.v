`timescale 1ns/1ps

module tb_pipe_top;

    // pipe_top now pulls every network/quantization size from the package;
    // REG_WIDTH is the only parameter left on the module.
    import pipe_params::*;

    parameter REG_WIDTH  = 16;
    parameter CLK_PERIOD = 10;

    // Local aliases so the stimulus reads the same as before the param strip
    localparam ACTIVATIONS = HIDDEN_ACTIVATION_SIZE;
    localparam PIX_WIDTH   = HIDDEN_PIXEL_WIDTH;

    // Pixel writes take ACTIVATIONS cycles, the hidden matmul another
    // M+N+K-2 = 799, the output matmul 25. Round well up.
    localparam TIMEOUT_NS = 100000;

    // DUT inputs
    reg clk;
    reg [REG_WIDTH-1:0] matrix_control_in;

    reg                           pixel_wr_en;
    reg [PIX_WIDTH-1:0]           pixel_wr_data;
    reg [$clog2(ACTIVATIONS)-1:0] pixel_wr_address;

    // DUT outputs
    wire [REG_WIDTH-1:0] matrix_status_out;
    wire [REG_WIDTH-1:0] predicted_result_out;

    wire idle = matrix_status_out[0];

    pipe_top #(
        .REG_WIDTH (REG_WIDTH)
    ) uut (
        .clk                  (clk),

        .matrix_control_in    (matrix_control_in),
        .matrix_status_out    (matrix_status_out),
        .predicted_result_out (predicted_result_out),

        .pixel_wr_en          (pixel_wr_en),
        .pixel_wr_data        (pixel_wr_data),
        .pixel_wr_address     (pixel_wr_address)
    );

    // Free-running system clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Stimulus and goldens from scripts/model_pipeline/pipeline.py.
    //
    // Run `python3 scripts/model_pipeline/pipeline.py --index N` first: it
    // writes golden_*.hex into tb/pipe/
    // ------------------------------------------------------------------
    reg [PIX_WIDTH-1:0]               pixels          [0:ACTIVATIONS-1];
    reg [HIDDEN_ACCUM_WIDTH-1:0]      exp_hidden_relu [0:HIDDEN_NEURONS_SIZE-1];
    reg [OUTPUT_ACTIVATION_WIDTH-1:0] exp_requantized [0:HIDDEN_NEURONS_SIZE-1];
    reg [OUTPUT_ACCUM_WIDTH-1:0]      exp_output      [0:OUTPUT_OUT_SIZE-1];
    reg [3:0]                         exp_argmax      [0:0];

    task load_goldens();
        $readmemh("golden/golden_pixels.hex",      pixels);
        $readmemh("golden/golden_hidden_relu.hex", exp_hidden_relu);
        $readmemh("golden/golden_requantized.hex", exp_requantized);
        $readmemh("golden/golden_output.hex",      exp_output);
        $readmemh("golden/golden_argmax.hex",      exp_argmax);
    endtask

    // $readmemh on a missing file is only a warning and leaves every array at
    // zero -- which compares equal against a DUT that also produced zeros. A
    // silent pass is worse than no test, so refuse to run on empty goldens.
    task check_goldens_loaded();
        integer nonzero;
        nonzero = 0;
        for (int i = 0; i < ACTIVATIONS; i++)
            if (pixels[i] != 0) nonzero++;
        for (int i = 0; i < HIDDEN_NEURONS_SIZE; i++)
            if (exp_hidden_relu[i] != 0) nonzero++;
        for (int i = 0; i < OUTPUT_OUT_SIZE; i++)
            if (exp_output[i] != 0) nonzero++;

        if (nonzero == 0) begin
            $display("Goldens are all zero -- did they load?");
            $display("  $readmemh resolves against the CWD: run via");
            $display("  `cmake --build . --target run_pipe_tb`, and run");
            $display("  `python3 scripts/model_pipeline/pipeline.py` first.");
            $fatal(1, "empty goldens");
        end
    endtask

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    task write_pixel_data();
        @(negedge clk);
        for(int i = 0; i < ACTIVATIONS; i++) begin
            pixel_wr_en <= 1'b1;
            pixel_wr_data <= pixels[i];
            pixel_wr_address <= i[$clog2(ACTIVATIONS)-1:0];
            @(negedge clk);
        end
        pixel_wr_en = 1'b0;
    endtask

    task write_go();
        @(negedge clk);
        matrix_control_in <= 'd1;
        @(negedge clk);
        matrix_control_in <= 'd0;
    endtask

    // compute_idle is (state == IDLE), which is already high before GO, so
    // waiting on idle == 1 alone falls straight through. Wait for the FSM to
    // leave IDLE first, then for it to come back.
    task wait_compute_idle();
        wait(idle == 0);
        wait(idle == 1);
        @(posedge clk);
    endtask

    // Drives the run: GO, then back to idle once both layers have gone.
    task run_compute();
        write_go();
        $display("[%0t] Wrote GO (idle=%0b).", $time, idle);
        wait_compute_idle();
        $display("[%0t] Compute idle again.", $time);
    endtask

    // ------------------------------------------------------------------
    // Stage checks, one task per tap point. Each arms before GO, blocks on its
    // own valid qualifier, then compares against the goldens.
    //
    // matrix_mult_datapath registers c_out and c_out_valid on the same edge and
    // holds c_out until the next load_outputs, so sampling on the negedge
    // inside the valid window reads settled combinational logic downstream.
    // ------------------------------------------------------------------
    task check_hidden_relu();
        wait(uut.hidden_result_valid == 1'b1);
        @(negedge clk);
        for (int i = 0; i < HIDDEN_NEURONS_SIZE; i++) begin
            if (uut.relu_result[i] != exp_hidden_relu[i]) begin
                $display("[%0t] FAIL hidden_relu neuron %0d: expected %08h, got %08h",
                         $time, i, exp_hidden_relu[i], uut.relu_result[i]);
                $fatal(1, "hidden_relu mismatch");
            end
        end
        $display("[%0t] PASS hidden_relu %0d/%0d neurons",
                 $time, HIDDEN_NEURONS_SIZE, HIDDEN_NEURONS_SIZE);
    endtask

    task check_requantized();
        wait(uut.hidden_result_valid == 1'b1);
        @(negedge clk);
        for (int i = 0; i < HIDDEN_NEURONS_SIZE; i++) begin
            if (uut.rerequantize_result[i] != exp_requantized[i]) begin
                $display("[%0t] FAIL requantized neuron %0d: expected %04h, got %04h",
                         $time, i, exp_requantized[i], uut.rerequantize_result[i]);
                $fatal(1, "requantized mismatch");
            end
        end
        $display("[%0t] PASS requantized %0d/%0d neurons",
                 $time, HIDDEN_NEURONS_SIZE, HIDDEN_NEURONS_SIZE);
    endtask

    task check_output();
        wait(uut.output_result_valid == 1'b1);
        @(negedge clk);
        for (int i = 0; i < OUTPUT_OUT_SIZE; i++) begin
            if (uut.output_layer_result[i] != exp_output[i]) begin
                $display("[%0t] FAIL output class %0d: expected %08h, got %08h",
                         $time, i, exp_output[i], uut.output_layer_result[i]);
                $fatal(1, "output mismatch");
            end
        end
        $display("[%0t] PASS output %0d/%0d classes",
                 $time, OUTPUT_OUT_SIZE, OUTPUT_OUT_SIZE);
    endtask

    task check_argmax();
        wait(uut.output_result_valid == 1'b1);
        @(negedge clk);
        if (uut.argmax_idx_out != exp_argmax[0]) begin
            $display("[%0t] FAIL argmax: expected %0d, got %0d",
                     $time, exp_argmax[0], uut.argmax_idx_out);
            $display("       argmax.sv compares unsigned, so a negative logit");
            $display("       outranks every positive one -- see the output logits.");
            $fatal(1, "argmax mismatch");
        end
        $display("[%0t] PASS argmax %0d", $time, uut.argmax_idx_out);
    endtask

    // Standalone so the fork/join below can wait on every checker: a watchdog
    // inside the join would have to finish for the join to complete.
    initial begin
        #TIMEOUT_NS;
        $display("[%0t] FAIL timeout after %0d ns (idle=%0b).",
                 $time, TIMEOUT_NS, idle);
        $fatal(1, "timeout waiting for compute to finish");
    end

    // ------------------------------------------------------------------
    // Main sequence: load goldens, stream the image in, then run the compute
    // alongside the four stage checkers and wait for all of them.
    // ------------------------------------------------------------------
    initial begin
        matrix_control_in = {REG_WIDTH{1'b0}};
        pixel_wr_en       = 1'b0;
        pixel_wr_data     = {PIX_WIDTH{1'b0}};
        pixel_wr_address  = {$clog2(ACTIVATIONS){1'b0}};

        load_goldens();
        check_goldens_loaded();

        write_pixel_data();
        $display("[%0t] Wrote %0d pixels.", $time, ACTIVATIONS);

        fork
            run_compute();
            check_hidden_relu();
            check_requantized();
            check_output();
            check_argmax();
        join

        $display("[%0t] === TEST PASSED: hidden_relu, requantized, output, argmax all match pipeline.py ===",
                 $time);
        $display("[%0t] predicted %0d (predicted_result_out reads %0d -- port is undriven)",
                 $time, uut.argmax_layer_output_l, predicted_result_out);

        $finish;
    end

endmodule

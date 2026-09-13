`timescale 1ns/1ps

module tb_pipe_top;

    parameter REG_WIDTH   = 16;
    parameter NUERONS     = 16;
    parameter OUTPUT      = 10;
    parameter ACTIVATIONS = 28 * 28;

    parameter HIDDEN_WEIGHT_WIDTH = 16;
    parameter PIXEL_WIDTH         = 8;
    parameter OUTPUT_WEIGHT_WIDTH = 16;

    parameter HIDDEN_ACCUM_WIDTH = 32;
    parameter OUTPUT_ACCUM_WIDTH = 32;

    parameter CLK_PERIOD = 10;

    // DUT inputs
    reg clk;
    reg [REG_WIDTH-1:0] matrix_control_in;

    reg                              pixel_wr_en;
    reg [PIXEL_WIDTH-1:0]            pixel_wr_data;
    reg [$clog2(ACTIVATIONS)-1:0]    pixel_wr_address;

    // DUT outputs
    wire [REG_WIDTH-1:0] matrix_status_out;
    wire [REG_WIDTH-1:0] predicted_result_out;

    wire idle = matrix_status_out[0];

    pipe_top #(
        .REG_WIDTH           (REG_WIDTH),
        .NUERONS             (NUERONS),
        .OUTPUT              (OUTPUT),
        .ACTIVATIONS         (ACTIVATIONS),
        .HIDDEN_WEIGHT_WIDTH (HIDDEN_WEIGHT_WIDTH),
        .PIXEL_WIDTH         (PIXEL_WIDTH),
        .OUTPUT_WEIGHT_WIDTH (OUTPUT_WEIGHT_WIDTH),
        .HIDDEN_ACCUM_WIDTH  (HIDDEN_ACCUM_WIDTH),
        .OUTPUT_ACCUM_WIDTH  (OUTPUT_ACCUM_WIDTH)
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

    task write_pixel_data(); 
        @(negedge clk);
        for(int i = 0; i < 28 * 28; i++) begin
            pixel_wr_en <= 1'b1;
            pixel_wr_data <= 8'hCC;
            pixel_wr_address <= i[9:0];
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

    task wait_compute_idle();
        @(posedge clk);
        wait(idle == 1);
        @(posedge clk);
    endtask

    

    // ------------------------------------------------------------------
    // Main sequence - no stimulus yet, just let the BRAM $readmemh preloads
    // settle and hold the design idle so the wave dump has something to show.
    // ------------------------------------------------------------------
    initial begin
        matrix_control_in = {REG_WIDTH{1'b0}};
        pixel_wr_en       = 1'b0;
        pixel_wr_data     = {PIXEL_WIDTH{1'b0}};
        pixel_wr_address  = {$clog2(ACTIVATIONS){1'b0}};

        write_pixel_data();
        $display("[%0t] Wrote pixel data (idle=%0b, predicted=%0d).",
                 $time, idle, predicted_result_out);

        // Write go
        write_go();
        $display("[%0t] Wrote GO (idle=%0b, predicted=%0d).",
                 $time, idle, predicted_result_out);

        fork
            #10000;
            wait_compute_idle();
        join_any

        $display("[%0t] Finished (idle=%0b, predicted=%0d).",
                 $time, idle, predicted_result_out);

        $finish;
    end

endmodule

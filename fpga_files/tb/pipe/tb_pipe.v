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

    task write_pixel_data();
        @(negedge clk);
        for(int i = 0; i < ACTIVATIONS; i++) begin
            pixel_wr_en <= 1'b1;
            pixel_wr_data <= 8'hCC;
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
        pixel_wr_data     = {PIX_WIDTH{1'b0}};
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

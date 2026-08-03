`timescale 1ns/1ps

module tb_matrix_mult_top;

    parameter D_WIDTH = 4;
    parameter ACC_WIDTH = 16;
    parameter CLK_PERIOD = 10;

    // DUT inputs
    reg clk;
    reg req_valid;
    reg [D_WIDTH-1:0] a00, a01, a10, a11;
    reg [D_WIDTH-1:0] b00, b01, b10, b11;

    // DUT outputs
    wire done;
    wire [ACC_WIDTH-1:0] c00, c01, c10, c11;

    matrix_mult_top #(
        .D_WIDTH   (D_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) uut (
        .clk       (clk),
        .req_valid (req_valid),
        .done      (done),
        .a00 (a00), .a01 (a01), .a10 (a10), .a11 (a11),
        .b00 (b00), .b01 (b01), .b10 (b10), .b11 (b11),
        .c00 (c00), .c01 (c01), .c10 (c10), .c11 (c11)
    );

    // Free-running system clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Stimulus: 2x2 matrix multiply
    //   A = [1 2; 3 4]   B = [5 6; 7 8]
    //   Expected C = A*B = [19 22; 43 50]
    initial begin
        req_valid <= 1'b0;
        a00 <= 4'd1; a01 <= 4'd2; a10 <= 4'd3; a11 <= 4'd4;
        b00 <= 4'd5; b01 <= 4'd6; b10 <= 4'd7; b11 <= 4'd8;

        repeat (3) @(posedge clk);

        // Assert req_valid to kick off the FSM
        @(negedge clk);
        req_valid <= 1'b1;

        @(negedge clk);
        req_valid <= 1'b0;

        // Wait for the datapath to go busy, then wait until it's done
        wait (done == 1'b0);
        $display("[%0t] Compute started, done deasserted.", $time);

        wait (done == 1'b1);
        $display("[%0t] Compute finished.", $time);
        $display("[%0t] c00=%0d c01=%0d c10=%0d c11=%0d", $time, c00, c01, c10, c11);

        if (c00 !== 16'd19 || c01 !== 16'd22 || c10 !== 16'd43 || c11 !== 16'd50) begin
            $display("[%0t] MISMATCH: expected c00=19 c01=22 c10=43 c11=50", $time);
        end else begin
            $display("[%0t] PASS: matrix multiply result matches expected values", $time);
        end

        repeat (10) @(posedge clk);
        $display("[%0t] All stimulus sent.", $time);
        $finish;
    end

endmodule

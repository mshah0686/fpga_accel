// Simple timer to test data sending from SPI with commands

module simple_timer (
    input clk,

    input start,
    input clear,
    input stop,

    output [7:0] count
);

    localparam CYCLES_PER_SECOND = 25000000;
    //ocalparam CYCLES_PER_SECOND = 25;
    localparam CYCLE_COUNTER_WIDTH = 25;

    reg [7:0] count_q = 8'd0;
    reg [24:0] cycle_counter = CYCLES_PER_SECOND;
    reg timer_en = 1'b0;


    always @(posedge clk) begin
        if(start) begin
            // Start counting (no clear here)
            timer_en <= 1'b1;
        end else if(stop) begin
            // Stop counting
            timer_en <= 1'b0;
        end else if (clear) begin
            // Reset everyting
            count_q <= 8'b0;
            cycle_counter <= CYCLES_PER_SECOND; // Refill to expected
            // Disable counter
            timer_en <= 1'b0;
        end else begin
            if(cycle_counter == 25'b0) begin
                // Down counter hit! Increase counter + reset cycle counter
                cycle_counter <= CYCLES_PER_SECOND;
                count_q <= count_q + 8'b1;
            end else begin
                if(timer_en==1) 
                    // Decrease counter if enabled
                    cycle_counter <= cycle_counter - 25'b1;
            end
        end
    end

    assign count = count_q;


endmodule 
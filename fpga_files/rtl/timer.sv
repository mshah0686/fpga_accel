// Simple timer to test data sending from SPI with commands

module simple_timer (
    input clk,

    input start,
    input clear,
    input stop,

    output [7:0] count,
    output reg timer_en,

    output reg [3:0] tens_place,
    output reg [3:0] ones_place,

    output [3:0] dbg,
    output [3:0] led_dbg
);

    localparam CYCLES_PER_SECOND = 25000000;
    //localparam CYCLES_PER_SECOND = 25;
    localparam CYCLE_COUNTER_WIDTH = 25;
    localparam COUNTER_MAX = 99; // Display of 99

    reg [7:0] count_q = 8'd0;
    reg [24:0] cycle_counter = CYCLES_PER_SECOND;

    reg dummy_started = 1'b0;

    always @(posedge clk) begin
        if(start) begin
            // Start counting (no clear here)
            timer_en <= 1'b1;
            if(dummy_started !== 1'b1) begin
                dummy_started <= 1'b1;
                count_q <= 8'b0;
            end
        end else if(stop) begin
            // Stop counting
            timer_en <= 1'b0;
        end else if (clear) begin
            // Reset everyting
            count_q <= 8'b0;

            cycle_counter <= CYCLES_PER_SECOND; // Refill to expected
        end else begin
            if(cycle_counter == 25'b0) begin
                // Down counter hit! Increase counter + reset cycle counter
                cycle_counter <= CYCLES_PER_SECOND;
                count_q <= (count_q == COUNTER_MAX) ? 8'b0 : count_q + 8'b1;
            end else begin
                if(timer_en== 1'b1) begin
                    // Decrease counter if enabled
                    cycle_counter <= cycle_counter - 25'b1;
                end
            end
        end
    end

    assign count = count_q;

    assign dbg = {timer_en, start, stop, clear};
    assign led_dbg = count_q[3:0];


    // Convert to binary for output
    integer i;
    always @(*) begin
        tens_place = 4'b0;
        ones_place = 4'b0;
        for(i = 7; i >=0; i = i - 1) begin
            if(tens_place >= 5) tens_place = tens_place + 3;
            if(ones_place >= 5) ones_place = ones_place + 3;

            // shift
            tens_place = {tens_place[2:0], ones_place[3]};
            ones_place = {ones_place[2:0], count[i]};
        end
    end

endmodule 
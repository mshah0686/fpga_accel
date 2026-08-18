module UART_TX
#(
    parameter BAUD_RATE=115200
)
(
    input clk,
    // Valid qualifies data
    input valid,
    input [7:0] data,

    // uart signal out
    output reg uart_out,
    output ready
);

    // State machine states
    parameter [1:0] IDLE = 2'd0,
                    START = 2'd1,
                    SEND = 2'd2,
                    STOP = 2'd3;

    // 25Mhz Clk => Wait in each state based on baud rate baud rate
    parameter clk_tick_wait = 217;

    // Count clk cycles in state to time UART
    reg [7:0] clk_tick_counter = 0;
    // Latch data input
    reg [7:0] data_save;
    // Latch current digit being sent
    reg [3:0] digit_count;
    // FSM states
    reg [1:0] current_state, next_state;

    wire count_finish_flag;
    assign count_finish_flag = clk_tick_counter == clk_tick_wait;

    // Assign next state
    always @(posedge clk) begin
        current_state <= next_state;
    end

    // Next state logic + output logic
    always @(*) begin
        next_state = IDLE;
        uart_out = 1;

        case(current_state)

            // In Idle - wait for valid
            IDLE: begin
                uart_out = 1;
                if(valid) begin
                    next_state = START;
                end else begin
                    next_state = IDLE;
                end
            end

            // Start bit with drive to 0
            START: begin
                // Drive low
                uart_out = 0;
                if(count_finish_flag)
                    next_state = SEND;
                else
                    next_state = START;
            end

            // Send current digit (until all 7 sent)
            SEND: begin
                uart_out = data_save[digit_count];
                if(digit_count == 7 && count_finish_flag)
                    next_state = STOP;
                else
                    next_state = SEND;

            end

            // Stop bit
            STOP: begin
                uart_out = 1;
                if(count_finish_flag)
                    next_state = IDLE;
                else
                    next_state = STOP;

            end
            default: begin
                next_state = IDLE;
                uart_out = 1'b1;
            end

        endcase

    end

    // Latch data being sent
    always @(posedge clk) begin
        if(valid && current_state == IDLE)
            data_save <= data;
    end

    // Count clock cycles in state
    always @(posedge clk) begin
        if(current_state == IDLE) begin
            clk_tick_counter <= 0;
        end else if(current_state == START || current_state == SEND || current_state == STOP) begin
            // Increment counters in state until period for bit
            // Once you hit period, state will transition and you can reset
            if(count_finish_flag)
                clk_tick_counter <= 0;
            else
                clk_tick_counter <= clk_tick_counter + 1;
        end else
            clk_tick_counter <= 0;
    end

    // Increment digit count on state transitions
    always @(posedge clk) begin
        if(current_state == SEND) begin
            if(count_finish_flag) begin
                digit_count <= digit_count + 1;
            end
        end else begin
            digit_count <= 0;
        end
    end

    assign ready = (current_state == IDLE);



endmodule
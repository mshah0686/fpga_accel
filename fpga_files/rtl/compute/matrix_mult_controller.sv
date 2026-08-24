module matrix_mult_controller (
    input clk,
    input req_valid, // Pulse beat in (only captured when idle)

    // Control signals to datapath
    output reg execute,
    output reg load_outputs,
    input datapath_idle,

    output reg controller_idle
);

    // FSM state encoding
    typedef enum logic [1:0] {
        IDLE = 'd0,
        EXECUTE = 'd1,
        WAIT = 'd2,
        SAVE = 'd3
    } datapath_state_t;

    datapath_state_t current_state , next_state;

    // State register
    always @(posedge clk) begin
        current_state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if(req_valid) begin
                    next_state = EXECUTE;
                end else begin
                    next_state = IDLE;
                end
            end

            EXECUTE: begin
                next_state = WAIT;
            end

            WAIT: begin
                if(datapath_idle) begin
                    next_state = SAVE;
                end else begin
                    next_state = WAIT;
                end
            end

            SAVE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        execute      = 1'b0;
        load_outputs = 1'b0;
        controller_idle = 1'b1;

        case (current_state)
            IDLE: begin
                controller_idle = 1'b1;
            end

            EXECUTE: begin
                execute = 1'b1;
                controller_idle = 1'b0;
            end

            WAIT: begin
                controller_idle = 1'b0;
            end

            SAVE: begin
                load_outputs = 1'b1;
                controller_idle = 1'b0;
            end

            default: begin
                execute = 1'b0;
                load_outputs = 1'b0;
                controller_idle = 1'b1;
            end
        endcase
    end

endmodule

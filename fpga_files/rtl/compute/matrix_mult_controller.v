module matrix_mult_controller (
    input clk,
    input req_valid, // Pulse beat in (only captured when idle)

    // Control signals to datapath
    output reg load_values,
    output reg execute,
    output reg load_outputs,
    input dpath_idle,

    output reg idle
);

    // FSM state encoding
    localparam [2:0] IDLE = 3'd0,
                     LOAD = 3'd1,
                     EXECUTE = 3'd2,
                     WAIT = 3'd3,
                     SAVE = 3'd4;

    reg [2:0] current_state = IDLE;
    reg [2:0] next_state;

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
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                next_state = EXECUTE;
            end

            EXECUTE: begin
                next_state = WAIT;
            end

            WAIT: begin
                if(dpath_idle) begin
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
        load_values  = 1'b0;
        execute      = 1'b0;
        load_outputs = 1'b0;
        idle         = 1'b0;

        case (current_state)
            IDLE: begin
                idle = 1'b1;
            end

            LOAD: begin
                load_values = 1'b1;
            end

            EXECUTE: begin
                execute = 1'b1;
            end

            WAIT: begin
            end

            SAVE: begin
                load_outputs = 1'b1;
            end

            default: begin
                idle = 1'b1;
            end
        endcase
    end

endmodule

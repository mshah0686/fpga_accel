module matrix_mult_controller (
    input clk,
    input req_valid,

    // Control signals to datapath
    output reg load_values,
    output reg select_k,
    output reg enable,
    output reg clear,
    output reg load_outputs,

    output reg done
);

    // FSM state encoding
    parameter [2:0] IDLE = 3'd0,
                     LOAD = 3'd1,
                     K1   = 3'd2,
                     K2   = 3'd3,
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
                next_state = K1;
            end

            K1: begin
                next_state = K2;
            end

            K2: begin
                next_state = SAVE;
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
        select_k     = 1'b0;
        enable       = 1'b0;
        clear        = 1'b0;
        load_outputs = 1'b0;
        done         = 1'b0;

        case (current_state)
            IDLE: begin
                done = 1'b1;
            end

            LOAD: begin
                clear = 1'b1;
                load_values = 1'b1;
            end

            K1: begin
                enable = 1'b1;
                select_k = 1'b0;
            end

            K2: begin
                enable = 1'b1;
                select_k = 1'b1;
            end

            SAVE: begin
                load_outputs = 1'b1;
            end

            default: begin
                done = 1'b1;
            end
        endcase
    end

endmodule

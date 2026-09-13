module pipe_control_fsm (
    input clk,
    
    input compute_go,
    output compute_idle,

    output hidden_go_pulse,
    input hidden_idle,

    output output_go_pulse,
    input output_idle

    // output argmax_go_pulse,
    // input argmax_idle
);

    typedef enum logic [1:0] {
        IDLE,
        STATE_GO,
        STATE_WAIT
    } state_t;

    typedef enum logic [0:0] {
        HIDDEN,
        OUTPUT
    } compute_block_t;

    state_t current_state, next_state;
    compute_block_t compute_block = HIDDEN;

    wire all_idle;
    assign all_idle = output_idle & hidden_idle; //& argmax_idle

    wire finished_stage_cycle; // Finished all stages
    assign finished_stage_cycle = all_idle && (compute_block == HIDDEN); // Finished last stage, reset compute state to HIDDEN

    always_ff @(posedge clk) begin
        current_state <= next_state;
    end

    always_comb begin
        next_state = IDLE;
        case(current_state)
            IDLE: begin
                if(compute_go) begin
                    next_state = STATE_GO;
                end else begin
                    next_state = IDLE;
                end
            end

            STATE_GO: begin
                next_state = STATE_WAIT;
            end

            STATE_WAIT: begin
                if(finished_stage_cycle) begin
                    next_state = IDLE;
                end else if(all_idle) begin
                    next_state = STATE_GO;
                end else begin
                    next_state = STATE_WAIT;
                end
            end
            default : begin
                next_state = IDLE;
            end
        endcase
    end

    // Move to next compute block on each GO pulse
    always_ff @(posedge clk) begin
        if(current_state == STATE_GO) begin
            case (compute_block)
                HIDDEN: compute_block <= OUTPUT;
                OUTPUT: compute_block <= HIDDEN;
                //ARGMAX: compute_block <= HIDDEN;
            endcase
        end
    end

    wire go_pulse;
    assign go_pulse = (current_state == STATE_GO);
    // Output go pulse based on current stage
    assign hidden_go_pulse = go_pulse & (compute_block == HIDDEN);
    assign output_go_pulse = go_pulse & (compute_block == OUTPUT);
    //assign argmax_go_pulse = go_pulse & (compute_block == ARGMAX);
    assign compute_idle = (current_state == IDLE);

endmodule
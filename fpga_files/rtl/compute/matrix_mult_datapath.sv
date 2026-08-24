module mult_datapath #(
    parameter D_WIDTH = 8,
    parameter ACC_WIDTH = 26,
    parameter M = 2,
    parameter K = 2,
    parameter N = 2
)(
    input clk,

    // Control signals - default load for now until BRAM
    input load_outputs,
    input execute,
    output idle,

    // Data inputs (Loaded at once for now)
    input  [M-1:0][K-1:0][D_WIDTH-1:0] a,
    input  [K-1:0][N-1:0][D_WIDTH-1:0] b,

    // Data outputs (A_VER x A_HOR * B_VER x B_HOR)
    output logic [M-1:0][N-1:0][ACC_WIDTH-1:0] c_out
);

    typedef enum logic [0:0] {
        IDLE = 'd0,
        EXECUTE = 'd1
    } datapath_state_t;

    localparam EXECUTION_CYCLES = M + N + K - 2; // Hardcoded for now
    localparam EXECUTION_FINISH_CYCLES = EXECUTION_CYCLES - 1;

    datapath_state_t current_state, next_state;
    logic [$clog2(EXECUTION_CYCLES) - 1 :0] execution_cycle_counter;

    always @(posedge clk) begin
        current_state <= next_state;
    end

    always @(posedge clk) begin
        if(current_state == EXECUTE) begin
            execution_cycle_counter <= execution_cycle_counter + 1;
        end else begin
            execution_cycle_counter = 'd0;
        end
    end

    always @(*) begin
        next_state = current_state; // default: hold

        case (current_state)
            IDLE: begin
                if(execute) begin
                    next_state = EXECUTE;
                end
            end
            EXECUTE: begin
                if(execution_cycle_counter == EXECUTION_FINISH_CYCLES) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    assign idle = current_state == IDLE;

    always @(posedge clk) begin
        if (load_outputs) begin
            c_out <= c_out_conns;
        end
    end

    // SYSTOLIC ARRAY DRIVERS
    logic [M-1:0][D_WIDTH-1:0] M_edge_drive; // Right edge drive
    logic [N-1:0][D_WIDTH-1:0] N_edge_drive; // Top EDGE drive

    // M_edge meta
    logic [M-1:0] M_edge_valid;
    logic [M-1:0] M_edge_first;

    // N-edge  meta
    logic [N-1:0] N_edge_valid;
    logic [N-1:0] N_edge_first;

    integer m_drive_loop;
    always_comb begin
        for(m_drive_loop = 0; m_drive_loop < M; m_drive_loop ++) begin
            // Valid drive
            if(current_state == EXECUTE && m_drive_loop <= int'(execution_cycle_counter) && int'(execution_cycle_counter) < (m_drive_loop + K) ) begin
                M_edge_valid[m_drive_loop] = 'd1;
            end else begin
                M_edge_valid[m_drive_loop] = 'd0;
            end

            // First drive
            if(current_state == EXECUTE && m_drive_loop == int'(execution_cycle_counter)) begin
                M_edge_first[m_drive_loop] = 'd1;
            end else begin
                M_edge_first[m_drive_loop] = 'd0;
            end

            // Data drive
            M_edge_drive[m_drive_loop] = 'd0;
            if(current_state == EXECUTE && M_edge_valid[m_drive_loop]) begin
                M_edge_drive[m_drive_loop] = a[m_drive_loop][int'(execution_cycle_counter) - m_drive_loop];
            end

            left_to_right_conns[m_drive_loop][0] = M_edge_drive[m_drive_loop];
            left_to_right_valid_conns[m_drive_loop][0] = M_edge_valid[m_drive_loop];
            left_to_right_first_conns[m_drive_loop][0] = M_edge_first[m_drive_loop];
        end
    end

    integer n_drive_loop;
    always_comb begin
        for(n_drive_loop = 0; n_drive_loop < N; n_drive_loop ++) begin
            // Valid drive
            if(current_state == EXECUTE && n_drive_loop <= int'(execution_cycle_counter) && int'(execution_cycle_counter) < (n_drive_loop + K)) begin
                N_edge_valid[n_drive_loop] = 'd1;
            end else begin
                N_edge_valid[n_drive_loop] = 'd0;
            end

            // First drive
            if(current_state == EXECUTE && n_drive_loop == int'(execution_cycle_counter)) begin
                N_edge_first[n_drive_loop] = 'd1;
            end else begin
                N_edge_first[n_drive_loop] = 'd0;
            end

            // Data drive
            N_edge_drive[n_drive_loop] = 'd0;
            if(current_state == EXECUTE && N_edge_valid[n_drive_loop]) begin
                N_edge_drive[n_drive_loop] = b[int'(execution_cycle_counter) - n_drive_loop][n_drive_loop];
            end


            up_to_down_conns[0][n_drive_loop] = N_edge_drive[n_drive_loop];
            up_to_down_first_conns[0][n_drive_loop] = N_edge_first[n_drive_loop];
            up_to_down_valid_conns[0][n_drive_loop] = N_edge_valid[n_drive_loop];
        end
    end

    // Systolic array connection
    logic [M:0][N:0][D_WIDTH-1:0] left_to_right_conns;
    logic [M:0][N:0][D_WIDTH-1:0] up_to_down_conns;
    logic [M:0][N:0] left_to_right_valid_conns;
    logic [M:0][N:0] up_to_down_valid_conns;
    logic [M:0][N:0] left_to_right_first_conns;
    logic [M:0][N:0] up_to_down_first_conns;

    logic [M-1:0][N-1:0][ACC_WIDTH-1:0] c_out_conns;

    genvar r;
    genvar c;
    generate
        for(r = 0; r < M; r=r+1) begin : row_gen
            for(c=0; c < N; c=c+1) begin : col_gen
                systolic_mac #(.D_WIDTH(D_WIDTH), .ACC_WIDTH(ACC_WIDTH))
                systolic_pe_u (
                    .clk(clk), 
                    .a_in(left_to_right_conns[r][c]),
                    .b_in(up_to_down_conns[r][c]),
                    .valid_a_in(left_to_right_valid_conns[r][c]),
                    .valid_b_in(up_to_down_valid_conns[r][c]),
                    .first_in_a(left_to_right_first_conns[r][c]),
                    .first_in_b(up_to_down_first_conns[r][c]),

                    .a_out(left_to_right_conns[r][c+1]),
                    .b_out(up_to_down_conns[r+1][c]),
                    .valid_a_out(left_to_right_valid_conns[r][c+1]),
                    .valid_b_out(up_to_down_valid_conns[r+1][c]),
                    .first_a_out(left_to_right_first_conns[r][c+1]),
                    .first_b_out(up_to_down_first_conns[r+1][c]),

                    .c_out(c_out_conns[r][c])
                );
            end
        end
    endgenerate



endmodule 
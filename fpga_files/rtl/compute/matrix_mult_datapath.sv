module mult_datapath #(
    parameter DATA_WIDTH = 8, // A and B inputs must be same size
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

    // Data outputs (A_VER x A_HOR * B_VER x B_HOR)
    output logic [M-1:0][N-1:0][ACC_WIDTH-1:0] c_out,


    // BRAM interfaces
    output logic [M-1:0][$clog2(K)-1:0] A_req_addr,
    output logic [M-1:0] A_req_en,
    input  [M-1:0][DATA_WIDTH-1:0] A_req_data,

    output logic [N-1:0][$clog2(K)-1:0] B_req_addr,
    output logic [N-1:0] B_req_en,
    input  [N-1:0][DATA_WIDTH-1:0] B_req_data
);
    localparam EXECUTION_CYCLES = M + N + K - 2; // Hardcoded for now
    localparam EXECUTION_FINISH_CYCLES = EXECUTION_CYCLES - 1;
    localparam M_ADDR_WIDTH = (M > 1) ? $clog2(M) : 1;
    localparam N_ADDR_WIDTH = (N > 1) ? $clog2(N) : 1;
    localparam K_ADDR_WIDTH = (K > 1) ? $clog2(K) : 1;

    localparam M_CONN_WIDTH = $clog2(M +1);
    localparam N_CONN_WIDTH = $clog2(N +1);

    localparam COUNTER_WIDTH = $clog2(EXECUTION_CYCLES);

    typedef enum logic [0:0] {
        IDLE = 'd0,
        EXECUTE = 'd1
    } datapath_state_t;

    datapath_state_t current_state, next_state;
    logic [COUNTER_WIDTH-1:0] execution_cycle_counter;

    always @(posedge clk) begin
        current_state <= next_state;
    end

    always @(posedge clk) begin
        if(current_state == EXECUTE) begin
            execution_cycle_counter <= execution_cycle_counter + 1;
        end else begin
            execution_cycle_counter <= 'd0;
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

    // M_edge meta
    logic [M-1:0] M_edge_valid;
    logic [M-1:0] M_edge_first;

    // N-edge  meta
    logic [N-1:0] N_edge_valid;
    logic [N-1:0] N_edge_first;

    logic[M_ADDR_WIDTH:0] m_drive_loop;
    always_comb begin
        for(m_drive_loop = 0; m_drive_loop < M; m_drive_loop ++) begin
            // Valid drive
            if(current_state == EXECUTE && 
                (COUNTER_WIDTH'(m_drive_loop) <= execution_cycle_counter) 
                && (execution_cycle_counter < COUNTER_WIDTH'(m_drive_loop + K)) ) begin
                M_edge_valid[M_ADDR_WIDTH'(m_drive_loop)] = 'd1;
            end else begin
                M_edge_valid[M_ADDR_WIDTH'(m_drive_loop)] = 'd0;
            end

            // First drive
            if(current_state == EXECUTE && COUNTER_WIDTH'(m_drive_loop) == execution_cycle_counter) begin
                M_edge_first[M_ADDR_WIDTH'(m_drive_loop)] = 'd1;
            end else begin
                M_edge_first[M_ADDR_WIDTH'(m_drive_loop)] = 'd0;
            end

            // BRAM request for values
            // Request on same cycle to latch into PE
            A_req_en[M_ADDR_WIDTH'(m_drive_loop)] = M_edge_valid[M_ADDR_WIDTH'(m_drive_loop)];
            if(current_state == EXECUTE && M_edge_valid[M_ADDR_WIDTH'(m_drive_loop)]) begin
                A_req_addr[M_ADDR_WIDTH'(m_drive_loop)] = K_ADDR_WIDTH'(execution_cycle_counter - m_drive_loop);
            end else begin
                A_req_addr[M_ADDR_WIDTH'(m_drive_loop)] = 'd0;
            end

            // BRAM response
            left_to_right_conns[M_CONN_WIDTH'(m_drive_loop)][0] = A_req_data[M_ADDR_WIDTH'(m_drive_loop)];
            // Valid/first conns
            left_to_right_valid_conns[M_CONN_WIDTH'(m_drive_loop)][0] = M_edge_valid[M_ADDR_WIDTH'(m_drive_loop)];
            left_to_right_first_conns[M_CONN_WIDTH'(m_drive_loop)][0] = M_edge_first[M_ADDR_WIDTH'(m_drive_loop)];
        end
    end

    logic[N_ADDR_WIDTH:0] n_drive_loop;
    always_comb begin
        for(n_drive_loop = 0; n_drive_loop < N; n_drive_loop ++) begin
            // Valid drive
            if(current_state == EXECUTE && 
                (COUNTER_WIDTH'(n_drive_loop) <= execution_cycle_counter) 
                && (execution_cycle_counter < COUNTER_WIDTH'(n_drive_loop + K)) ) begin
                N_edge_valid[N_ADDR_WIDTH'(n_drive_loop)] = 'd1;
            end else begin
                N_edge_valid[N_ADDR_WIDTH'(n_drive_loop)] = 'd0;
            end

            // First drive
            if(current_state == EXECUTE && COUNTER_WIDTH'(n_drive_loop) == execution_cycle_counter) begin
                N_edge_first[N_ADDR_WIDTH'(n_drive_loop)] = 'd1;
            end else begin
                N_edge_first[N_ADDR_WIDTH'(n_drive_loop)] = 'd0;
            end

            // BRAM reqeuest for values
            B_req_en[N_ADDR_WIDTH'(n_drive_loop)] = N_edge_valid[N_ADDR_WIDTH'(n_drive_loop)];
            if(current_state == EXECUTE && N_edge_valid[N_ADDR_WIDTH'(n_drive_loop)]) begin
                B_req_addr[N_ADDR_WIDTH'(n_drive_loop)] = K_ADDR_WIDTH'(execution_cycle_counter - n_drive_loop);
            end else begin
                B_req_addr[N_ADDR_WIDTH'(n_drive_loop)] = 'd0;
            end

            up_to_down_conns[0][N_CONN_WIDTH'(n_drive_loop)] = B_req_data[N_ADDR_WIDTH'(n_drive_loop)];
            up_to_down_first_conns[0][N_CONN_WIDTH'(n_drive_loop)] = N_edge_first[N_ADDR_WIDTH'(n_drive_loop)];
            up_to_down_valid_conns[0][N_CONN_WIDTH'(n_drive_loop)] = N_edge_valid[N_ADDR_WIDTH'(n_drive_loop)];
        end
    end

    // Systolic array connection
    logic [M:0][N:0][DATA_WIDTH-1:0] left_to_right_conns;
    logic [M:0][N:0][DATA_WIDTH-1:0] up_to_down_conns;
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
                systolic_mac #(.D_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH))
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
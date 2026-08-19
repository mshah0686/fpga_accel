module mult_datapath #(
    parameter D_WIDTH = 8,
    parameter ACC_WIDTH = 24
)(
    input clk,

    // Control signals
    input load_values,
    input execute,
    input load_outputs,
    output idle,

    // Data inputs (2x2 matrices, indexed [row][col])
    input  [1:0][1:0][D_WIDTH-1:0] a,
    input  [1:0][1:0][D_WIDTH-1:0] b,

    // Data outputs (2x2 matrix, indexed [row][col])
    output reg [1:0][1:0][ACC_WIDTH-1:0] c_out
);

    localparam IDLE    = 2'd0;
    localparam EXECUTE = 2'd1;
    localparam EXECUTION_CYCLES = 3; // Hardcoded for now

    reg [1:0] current_state, next_state;
    reg [3:0] cycle_counter;

    always @(posedge clk) begin
        current_state <= next_state;
    end

    always @(posedge clk) begin
        if(current_state == EXECUTE) begin
            cycle_counter <= cycle_counter + 1;
        end else begin
            cycle_counter = 4'd0;
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
                if(cycle_counter == EXECUTION_CYCLES) begin
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


    // Edge driver registers (index = row for A left edge, col for B top edge)
    reg [1:0][D_WIDTH-1:0] A_edge_drive;
    reg [1:0][D_WIDTH-1:0] B_edge_drive;
    reg [1:0]              valid_a_edge_drive;
    reg [1:0]              first_a_edge_drive;
    reg [1:0]              valid_b_edge_drive;
    reg [1:0]              first_b_edge_drive;

    reg [3:0] a_drive;
    always @(*) begin
        for(a_drive = 4'd0; a_drive < 4'd2; a_drive = a_drive + 4'd1) begin
            // valid: 2-cycle window starting at this row's launch cycle
            valid_a_edge_drive[a_drive[0]] = (current_state == EXECUTE &&
                                              cycle_counter >= a_drive &&
                                              cycle_counter <  a_drive + 4'd2);
            // data: k = cycle_counter - row (diagonal skew), narrowed to 1-bit index
            A_edge_drive[a_drive[0]] = valid_a_edge_drive[a_drive[0]] ?
                                       a[a_drive[0]][1'(cycle_counter - a_drive)] : 'd0;
            // first: assert only on this row's leading (k=0) cycle
            first_a_edge_drive[a_drive[0]] = (current_state == EXECUTE &&
                                              cycle_counter == a_drive);
        end
    end

    reg [3:0] b_drive;
    always @(*) begin
        for(b_drive = 4'd0; b_drive < 4'd2; b_drive = b_drive + 4'd1) begin
            // valid: 2-cycle window starting at this column's launch cycle
            valid_b_edge_drive[b_drive[0]] = (current_state == EXECUTE &&
                                              cycle_counter >= b_drive &&
                                              cycle_counter <  b_drive + 4'd2);
            // data: k = cycle_counter - col; b is [k][col], so indices swap vs A
            B_edge_drive[b_drive[0]] = valid_b_edge_drive[b_drive[0]] ?
                                       b[1'(cycle_counter - b_drive)][b_drive[0]] : 'd0;
            // first: assert only on this column's leading (k=0) cycle
            first_b_edge_drive[b_drive[0]] = (current_state == EXECUTE &&
                                              cycle_counter == b_drive);
        end
    end

    // Systolic array connection
    wire [2:0][2:0][D_WIDTH-1:0] a_conns;
    wire [2:0][2:0][D_WIDTH-1:0] b_conns;
    wire [2:0][2:0] valid_a_conns;
    wire [2:0][2:0] valid_b_conns;
    wire [2:0][2:0] first_in_a_conns;
    wire [2:0][2:0] first_in_b_conns;

    wire [1:0][1:0][ACC_WIDTH-1:0] c_out_conns;

    // Drive the A left-edge column (row-indexed) from the driver regs
    assign a_conns[0][0]          = A_edge_drive[0];
    assign a_conns[1][0]          = A_edge_drive[1];
    assign valid_a_conns[0][0]    = valid_a_edge_drive[0];
    assign valid_a_conns[1][0]    = valid_a_edge_drive[1];
    assign first_in_a_conns[0][0] = first_a_edge_drive[0];
    assign first_in_a_conns[1][0] = first_a_edge_drive[1];

    // Drive the B top-edge row (col-indexed) from the driver regs
    assign b_conns[0][0]          = B_edge_drive[0];
    assign b_conns[0][1]          = B_edge_drive[1];
    assign valid_b_conns[0][0]    = valid_b_edge_drive[0];
    assign valid_b_conns[0][1]    = valid_b_edge_drive[1];
    assign first_in_b_conns[0][0] = first_b_edge_drive[0];
    assign first_in_b_conns[0][1] = first_b_edge_drive[1];

    genvar r;
    genvar c;
    generate
        for(r = 0; r < 2; r=r+1) begin : row_gen
            for(c=0; c<2; c=c+1) begin : col_gen
                systolic_mac #(.D_WIDTH(D_WIDTH), .ACC_WIDTH(ACC_WIDTH))
                systolic_pe_u (
                    .clk(clk), 
                    .a_in(a_conns[r][c]),
                    .b_in(b_conns[r][c]),
                    .valid_a_in(valid_a_conns[r][c]),
                    .valid_b_in(valid_b_conns[r][c]),
                    .first_in_a(first_in_a_conns[r][c]),
                    .first_in_b(first_in_b_conns[r][c]),

                    .a_out(a_conns[r][c+1]),
                    .b_out(b_conns[r+1][c]),
                    .valid_a_out(valid_a_conns[r][c+1]),
                    .valid_b_out(valid_b_conns[r+1][c]),
                    .first_a_out(first_in_a_conns[r][c+1]),
                    .first_b_out(first_in_b_conns[r+1][c]),

                    .c_out(c_out_conns[r][c])
                );
            end
        end
    endgenerate



endmodule 
module matrix_mult_top #(
    parameter A_DATA_WIDTH = 8,
    parameter B_DATA_WIDTH = 8,
    parameter ACC_WIDTH = 26,
    parameter M = 2,
    parameter K = 2,
    parameter N = 2,
    parameter REG_WIDTH = 16,

    localparam MAX_DATA_WIDTH = (A_DATA_WIDTH > B_DATA_WIDTH) ? A_DATA_WIDTH : B_DATA_WIDTH, // Compute done at this data width
    localparam ADDR_WIDTH = $clog2(K) // Address within BRAM (K entries)
)(
    input clk,

    // Matrix control register interface (to/from register model)
    input  [REG_WIDTH-1:0] matrix_control_in, // LSB valid beat to enable it
    output [REG_WIDTH-1:0] matrix_control_out,

    // Matrix result (2x2, indexed [row][col])
    output [M-1:0][N-1:0][ACC_WIDTH-1:0] c
);

    // Controller <-> datapath control signals
    wire load_outputs;
    wire execute;
    wire datapath_idle;
    wire controller_idle;

    // Controller input/output & status
    wire matrix_top_idle;
    wire req_valid = matrix_control_in[0]; // Pulse in

    // Data path <-> BRAM
    wire [M-1:0] dpath_bram_a_r_en;
    wire [M-1:0][ADDR_WIDTH-1:0] dpath_bram_a_r_addr;
    wire [M-1:0][MAX_DATA_WIDTH-1:0] dpath_bram_a_r_data;
    // wire [M-1:0] dpath_bram_a_w_en;
    // wire [M-1:0][ADDR_WIDTH-1:0] dpath_bram_a_w_addr;
    // wire [M-1:0][DATA_WIDTH-1:0] dpath_bram_a_w_data;

    wire [N-1:0] dpath_bram_b_r_en;
    wire [N-1:0][ADDR_WIDTH-1:0] dpath_bram_b_r_addr;
    wire [N-1:0][MAX_DATA_WIDTH-1:0] dpath_bram_b_r_data;
    // wire [N-1:0] dpath_bram_b_w_en;
    // wire [N-1:0][ADDR_WIDTH-1:0] dpath_bram_b_w_addr;
    // wire [N-1:0][DATA_WIDTH-1:0] dpath_bram_b_w_data;

    // Control register out
    assign matrix_control_out = {{(REG_WIDTH-1){1'd0}}, controller_idle};

    matrix_mult_controller u_controller (
        .clk          (clk),
        .req_valid    (req_valid), // Pulse beat in
        .execute      (execute),
        .load_outputs (load_outputs),
        .datapath_idle   (datapath_idle),
        .controller_idle         (controller_idle)
    );

    mult_datapath #(
        .DATA_WIDTH(MAX_DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .M   (M),
        .K   (K),
        .N   (N)
    ) u_datapath (
        .clk          (clk),
        .execute      (execute),
        .load_outputs (load_outputs),
        .idle         (datapath_idle),

        // Output matrix
        .c_out        (c),

        // BRAM
        .A_req_addr(dpath_bram_a_r_addr),
        .A_req_en(dpath_bram_a_r_en),
        .A_req_data(dpath_bram_a_r_data),

        .B_req_addr(dpath_bram_b_r_addr),
        .B_req_en(dpath_bram_b_r_en),
        .B_req_data(dpath_bram_b_r_data)
    );

    // A BRAM - M Edge
    bram_wrapper #(
        .N(M),
        .BRAM_SIZE(K), // Per BRAM 
        .DATA_WIDTH(A_DATA_WIDTH),
        .OUTDATA_WIDTH(MAX_DATA_WIDTH),
        .SIGN_EXTEND(1),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX("weights/hidden")
    ) m_edge_bram_wrapper_u (
        .clk(clk),
        .r_en(dpath_bram_a_r_en),
        .r_addr(dpath_bram_a_r_addr),
        .r_data(dpath_bram_a_r_data),
        .w_en(),
        .w_addr(),
        .w_data()
    );

    // B BRAM - N Edge
    bram_wrapper #(
        .N(N),
        .BRAM_SIZE(K), // Per BRAM 
        .DATA_WIDTH(B_DATA_WIDTH),
        .OUTDATA_WIDTH(MAX_DATA_WIDTH),
        .SIGN_EXTEND(0),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX("weights/pixels")
    ) n_edge_bram_wrapper_u (
        .clk(clk),
        .r_en(dpath_bram_b_r_en),
        .r_addr(dpath_bram_b_r_addr),
        .r_data(dpath_bram_b_r_data),
        .w_en(),
        .w_addr(),
        .w_data()
    );



endmodule

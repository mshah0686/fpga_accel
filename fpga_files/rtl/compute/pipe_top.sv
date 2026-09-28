module pipe_top #(
    parameter REG_WIDTH = 16,

    parameter NUERONS = 16,
    parameter OUTPUT = 10,
    parameter ACTIVATIONS = 28 * 28,

    parameter HIDDEN_WEIGHT_WIDTH = 16,
    parameter PIXEL_WIDTH = 8,
    parameter OUTPUT_WEIGHT_WIDTH = 16,

    parameter HIDDEN_ACCUM_WIDTH = 32,
    parameter OUTPUT_ACCUM_WIDTH = 32
) (
    input clk,

    /*** RAL ***/
    input  [REG_WIDTH-1:0] matrix_control_in, // LSB is enable bit
    output [REG_WIDTH-1:0] matrix_status_out, // LSB is IDLE
    output [REG_WIDTH-1:0] predicted_result_out, // 32 Bit

    /*** PIXEL WRITE ***/
    input pixel_wr_en,
    input [PIXEL_WIDTH-1:0] pixel_wr_data, // FIXME::This is now two pixels coming in...needs adjusting in BRAM
    input [$clog2(ACTIVATIONS)-1:0] pixel_wr_address
);

    `include "weights/hidden_biases.svh"
    `include "weights/output_biases.svh"

    /***** HIDDEN LAYER *****/
    logic [NUERONS-1:0][HIDDEN_ACCUM_WIDTH -1:0] hidden_layer_result;
    logic hidden_go_pulse;
    logic hidden_idle;
    logic hidden_result_valid;

    // BRAM reads
    wire [NUERONS-1:0] hidden_weights_bram_rd_en;
    wire [NUERONS-1:0][$clog2(ACTIVATIONS)-1:0] hidden_weights_bram_rd_addr;
    wire [NUERONS-1:0][HIDDEN_WEIGHT_WIDTH-1:0] hidden_weights_bram_rd_data;
    wire hidden_pixel_bram_rd_en;
    wire [$clog2(ACTIVATIONS)-1:0]hidden_pixel_bram_rd_addr;
    wire [HIDDEN_WEIGHT_WIDTH-1:0] hidden_pixel_bram_rd_data; // Sized up in BRAM wrapper

    matrix_mult_top #(
        .A_DATA_WIDTH (HIDDEN_WEIGHT_WIDTH),
        .B_DATA_WIDTH(PIXEL_WIDTH),
        .ACC_WIDTH  (HIDDEN_ACCUM_WIDTH),
        .M          (NUERONS),
        .K          (ACTIVATIONS),
        .N          (1),
        .MAC_BIAS   (BIAS_HIDDEN)
    ) hidden_layer (
        .clk(clk),

        .go_pulse(hidden_go_pulse),
        .idle(hidden_idle),

        .result_valid(hidden_result_valid),
        .result(hidden_layer_result),

        .A_value_bram_r_en(hidden_weights_bram_rd_en),
        .A_value_bram_r_addr(hidden_weights_bram_rd_addr),
        .A_value_bram_r_data(hidden_weights_bram_rd_data),

        .B_value_bram_r_en(hidden_pixel_bram_rd_en),
        .B_value_bram_r_addr(hidden_pixel_bram_rd_addr),
        .B_value_bram_r_data(hidden_pixel_bram_rd_data)
    );

    /***** RELU LAYER *****/
    wire logic [NUERONS-1:0][HIDDEN_ACCUM_WIDTH -1:0] relu_result;
    logic [NUERONS-1:0][HIDDEN_ACCUM_WIDTH -1:0] relu_layer_result_l; // Hidden Layer + RelU output

    relu #(
        .DATA_SIZE(HIDDEN_ACCUM_WIDTH),
        .ARRAY_COLS(1),
        .ARRAY_ROWS(NUERONS)
    ) relu_u (
        .arr_in(hidden_layer_result),
        .arr_out(relu_result)
    );

    // Latch results after combinational drop
    always_ff @(posedge clk) begin
        if(hidden_result_valid) begin
            relu_layer_result_l <= relu_result;
        end
    end


    /***** OUTPUT LAYER *****/
    //logic [OUTPUT-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result_l;
    logic [OUTPUT-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result;
    logic output_go_pulse;
    logic output_idle;
    logic output_result_valid;

    // BRAM reads
    wire [OUTPUT-1:0] output_weights_bram_rd_en;
    wire [OUTPUT-1:0][$clog2(NUERONS)-1:0] output_weights_bram_rd_addr;
    wire [OUTPUT-1:0][OUTPUT_ACCUM_WIDTH-1:0] output_weights_bram_rd_data;

    wire output_activations_bram_rd_en;
    wire [$clog2(NUERONS)-1:0] output_activations_bram_rd_addr;
    logic [HIDDEN_ACCUM_WIDTH-1:0] output_activations_bram_rd_data;

    // Assign activation reads from RELU flops (simulate BRAM reads)
    always_comb begin
        if(output_activations_bram_rd_en) begin
            output_activations_bram_rd_data = relu_layer_result_l[output_activations_bram_rd_addr];
        end else begin
            output_activations_bram_rd_data = 'd0;
        end
    end

    // always_ff @(posedge clk) begin
    //     if(output_result_valid)
    //         output_layer_result_l <= output_layer_result;
    // end

    matrix_mult_top #(
        .A_DATA_WIDTH (OUTPUT_WEIGHT_WIDTH),
        .B_DATA_WIDTH(HIDDEN_ACCUM_WIDTH),
        .ACC_WIDTH  (OUTPUT_ACCUM_WIDTH),
        .M          (OUTPUT),
        .K          (NUERONS),
        .N          (1),
        .MAC_BIAS   (BIAS_OUTPUT)
    ) output_layer (
        .clk(clk),

        .go_pulse(output_go_pulse),
        .idle(output_idle),

        .result_valid(output_result_valid),
        .result(output_layer_result),

        .A_value_bram_r_en(output_weights_bram_rd_en),
        .A_value_bram_r_addr(output_weights_bram_rd_addr),
        .A_value_bram_r_data(output_weights_bram_rd_data),

        .B_value_bram_r_en(output_activations_bram_rd_en),
        .B_value_bram_r_addr(output_activations_bram_rd_addr),
        .B_value_bram_r_data(output_activations_bram_rd_data)
    );

    /***** ARGMAX LAYER *****/
    logic [$clog2(OUTPUT)-1:0] argmax_layer_output_l;
    logic [$clog2(OUTPUT)-1:0] argmax_idx_out;

    // Combinational
    argmax #(
        .SIZE(OUTPUT),
        .WIDTH(OUTPUT_ACCUM_WIDTH)
    ) argmax (
        .clk(clk),
        .inputs(output_layer_result),
        .index_of_max(argmax_idx_out)
    );

    always_ff @(posedge clk) begin
        if(output_result_valid) begin
            argmax_layer_output_l <= argmax_idx_out;
        end
    end

    /**** FSM CONTROL ****/
    pipe_control_fsm pipe_controller (
        .clk(clk),

        .compute_go(matrix_control_in[0]),
        .compute_idle(matrix_status_out[0]),

        .hidden_go_pulse(hidden_go_pulse),
        .hidden_idle(hidden_idle),

        .output_go_pulse(output_go_pulse),
        .output_idle(output_idle)

        // .argmax_go_pulse(argmax_go_pulse),
        // .argmax_idle(argmax_idle)
    );

    // Hidden Weights
    bram_wrapper #(
        .N(NUERONS), // Number of BRAMS
        .BRAM_SIZE(ACTIVATIONS), // Per BRAM size
        .DATA_WIDTH(HIDDEN_WEIGHT_WIDTH),
        .OUTDATA_WIDTH(HIDDEN_WEIGHT_WIDTH),
        .SIGN_EXTEND(1),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX("weights/hidden")
    ) hidden_weights_bram_u (
        .clk(clk),
        .r_en(hidden_weights_bram_rd_en),
        .r_addr(hidden_weights_bram_rd_addr),
        .r_data(hidden_weights_bram_rd_data),
        .w_en(),
        .w_addr(),
        .w_data()
    );

    // Pixel BRAM
    // FIXME::This will now have 16 bit write for 2 pixels at a time. Need adjusting in wrapper.
    bram_wrapper #(
        .N(1), // 1 BRAM only - flattened pixels
        .BRAM_SIZE(ACTIVATIONS), // Per BRAM 
        .DATA_WIDTH(PIXEL_WIDTH),
        .OUTDATA_WIDTH(HIDDEN_WEIGHT_WIDTH),
        .SIGN_EXTEND(0),
        .PRELOAD(0),
        .LOAD_FILE_PREFIX("")
    ) pixel_bram_u (
        .clk(clk),
        .r_en(hidden_pixel_bram_rd_en),
        .r_addr(hidden_pixel_bram_rd_addr),
        .r_data(hidden_pixel_bram_rd_data),

        .w_en(pixel_wr_en),
        .w_addr(pixel_wr_address),
        .w_data(pixel_wr_data)
    );

    // Output Weights
    bram_wrapper #(
        .N(OUTPUT),
        .BRAM_SIZE(NUERONS), // Per BRAM 
        .DATA_WIDTH(OUTPUT_WEIGHT_WIDTH),
        .OUTDATA_WIDTH(HIDDEN_ACCUM_WIDTH),
        .SIGN_EXTEND(1),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX("weights/output")
    ) output_weights_bram_u (
        .clk(clk),

        .r_en(output_weights_bram_rd_en),
        .r_addr(output_weights_bram_rd_addr),
        .r_data(output_weights_bram_rd_data),

        .w_en(),
        .w_addr(),
        .w_data()
    );


endmodule
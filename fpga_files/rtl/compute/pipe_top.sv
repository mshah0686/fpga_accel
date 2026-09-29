module pipe_top 
import pipe_params::*;
#(
    parameter REG_WIDTH = 16
) (
    input clk,

    /*** RAL ***/
    input  [REG_WIDTH-1:0] matrix_control_in, // LSB is enable bit
    output [REG_WIDTH-1:0] matrix_status_out, // LSB is IDLE
    output [REG_WIDTH-1:0] predicted_result_out, // 32 Bit

    /*** PIXEL WRITE ***/
    input pixel_wr_en,
    input [PIXEL_WIDTH-1:0] pixel_wr_data, // FIXME::This is now two pixels coming in...needs adjusting in BRAM
    input [$clog2(HIDDEN_ACTIVATION_SIZE)-1:0] pixel_wr_address
);

    `include "weights/hidden_biases.svh"
    `include "weights/output_biases.svh"

    /***** HIDDEN LAYER *****/
    logic [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_ACCUM_WIDTH -1:0] hidden_layer_result;
    logic hidden_go_pulse;
    logic hidden_idle;
    logic hidden_result_valid;

    // BRAM reads
    wire [HIDDEN_NEURONS_SIZE-1:0] hidden_weights_bram_rd_en;
    wire [HIDDEN_NEURONS_SIZE-1:0][$clog2(HIDDEN_ACTIVATION_SIZE)-1:0] hidden_weights_bram_rd_addr;
    wire [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_WEIGHT_WIDTH-1:0] hidden_weights_bram_rd_data;
    wire hidden_pixel_bram_rd_en;
    wire [$clog2(HIDDEN_ACTIVATION_SIZE)-1:0]hidden_pixel_bram_rd_addr;
    wire [HIDDEN_WEIGHT_WIDTH-1:0] hidden_pixel_bram_rd_data; // Sized up in BRAM wrapper

    matrix_mult_top #(
        .A_DATA_WIDTH (HIDDEN_WEIGHT_WIDTH),
        .B_DATA_WIDTH(PIXEL_WIDTH),
        .ACC_WIDTH  (HIDDEN_ACCUM_WIDTH),
        .M          (HIDDEN_NEURONS_SIZE),
        .K          (HIDDEN_ACTIVATION_SIZE),
        .N          (1),
        .MAC_BIAS   (BIAS_HIDDEN) // From weights file
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
    wire logic [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_ACCUM_WIDTH -1:0] relu_result;
    wire logic [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_ACCUM_WIDTH -1:0] rerequantize_result;
    logic [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_ACCUM_WIDTH -1:0] requantized_result_l; // Hidden Layer + RelU output

    relu #(
        .DATA_SIZE(HIDDEN_ACCUM_WIDTH),
        .ARRAY_COLS(1),
        .ARRAY_ROWS(HIDDEN_NEURONS_SIZE)
    ) relu_u (
        .arr_in(hidden_layer_result),
        .arr_out(relu_result)
    );

    requantize #(
        .INPUT_WIDTH(HIDDEN_ACCUM_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_ACTIVATION_WIDTH),
        .INPUT_SCALE_N(21), // FIXME::Need to parameterize
        .OUTPUT_SCALE_N(8),
        .ARRAY_HEIGHT(HIDDEN_NEURONS_SIZE),
        .ARRAY_WIDTH(1)
    ) reqquantize_u (
        .arr_in(relu_result),
        .arr_out(rerequantize_result)
    )

    // Latch results after combinational logic from RELU and REQUANTIZE
    always_ff @(posedge clk) begin
        if(hidden_result_valid) begin
            requantized_result_l <= rerequantize_result;
        end
    end

    /***** OUTPUT LAYER *****/
    //logic [OUTPUT-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result_l;
    logic [OUTPUT-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result;
    logic output_go_pulse;
    logic output_idle;
    logic output_result_valid;

    // BRAM reads
    wire [OUTPUT_OUT_SIZE-1:0] output_weights_bram_rd_en;
    wire [OUTPUT_OUT_SIZE-1:0][$clog2(HIDDEN_NEURONS_SIZE)-1:0] output_weights_bram_rd_addr;
    wire [OUTPUT_OUT_SIZE-1:0][OUTPUT_ACCUM_WIDTH-1:0] output_weights_bram_rd_data;

    wire output_activations_bram_rd_en;
    wire [$clog2(HIDDEN_NEURONS_SIZE)-1:0] output_activations_bram_rd_addr;
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
        .M          (OUTPUT_OUT_SIZE),
        .K          (HIDDEN_NEURONS_SIZE),
        .N          (1),
        .MAC_BIAS   (BIAS_OUTPUT) // From weights files
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
    logic [$clog2(OUTPUT_OUT_SIZE)-1:0] argmax_layer_output_l;
    logic [$clog2(OUTPUT_OUT_SIZE)-1:0] argmax_idx_out;

    // Combinational
    argmax #(
        .SIZE(OUTPUT_OUT_SIZE),
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
        .N(HIDDEN_NEURONS_SIZE), // Number of BRAMS
        .BRAM_SIZE(HIDDEN_ACTIVATION_SIZE), // Per BRAM size
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
        .BRAM_SIZE(HIDDEN_ACTIVATION_SIZE), // Per BRAM 
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
        .N(OUTPUT_OUT_SIZE),
        .BRAM_SIZE(HIDDEN_NEURONS_SIZE), // Per BRAM 
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
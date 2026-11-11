module pipe_top 
import pipe_params::*;
import fpga_params::*;
#(
    parameter REG_WIDTH = 16,
    parameter string WEIGHTS_DIR = "" // Prefix for weight .hex file names
) (
    input clk,

    /*** RAL ***/
    input  [REG_WIDTH-1:0] matrix_control_in, // LSB is enable bit
    output [REG_WIDTH-1:0] matrix_status_out, // LSB is IDLE
    output [REG_WIDTH-1:0] predicted_result_out, // 32 Bit

    /*** PIXEL WRITE ***/
    input pixel_wr_en,
    input [1:0][HIDDEN_PIXEL_WIDTH-1:0] pixel_wr_data, 
    input [ADDR_WIDTH-1:0] pixel_wr_address // From RAL (standard addr width)
);

    `include "hidden_biases.svh"
    `include "output_biases.svh"

    /***** HIDDEN LAYER *****/
    logic [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_ACCUM_WIDTH -1:0] hidden_layer_result;
    logic hidden_go_pulse;
    logic hidden_idle;
    logic hidden_result_valid;

    // BRAM reads
    wire [HIDDEN_NEURONS_SIZE-1:0] hidden_weights_bram_rd_en;
    wire [HIDDEN_NEURONS_SIZE-1:0][$clog2(HIDDEN_ACTIVATION_SIZE)-1:0] hidden_weights_bram_rd_addr;
    wire [HIDDEN_NEURONS_SIZE-1:0][HIDDEN_WEIGHT_WIDTH-1:0] hidden_weights_bram_rd_data;

    // Matrix -> conversion
    wire hidden_pixel_bram_rd_en;
    wire [$clog2(HIDDEN_ACTIVATION_SIZE)-1:0] hidden_pixel_bram_rd_addr;
    wire [HIDDEN_WEIGHT_WIDTH-1:0] hidden_pixel_bram_rd_data;
    // conversion -> BRAM
    wire [$clog2(HIDDEN_ACTIVATION_BRAM_SIZE)-1:0] converted_pixel_bram_rd_addr;
    wire [HIDDEN_PIXEL_BRAM_WIDTH-1:0] bram_pixel_bram_rd_data; // 2x size
    logic pixel_bram_rd_byte_select;

    always_ff @(posedge clk) begin
        if(hidden_pixel_bram_rd_en) begin
            pixel_bram_rd_byte_select <= hidden_pixel_bram_rd_addr[0]; // Byte select on LSB
        end
    end
    // Little endian - addr 0 is pixel 0, addr 1 is pixel 1
    assign hidden_pixel_bram_rd_data = pixel_bram_rd_byte_select ? {8'b0, bram_pixel_bram_rd_data[15:8]} : {8'b0, bram_pixel_bram_rd_data[7:0]}; // FIXME::Should be sized based on HIDDEN_WEIGHT_WIDTH parameter
    assign converted_pixel_bram_rd_addr = hidden_pixel_bram_rd_addr[$clog2(HIDDEN_ACTIVATION_SIZE)-1:1]; // Upper MSB for address (divide by 2)

    matrix_mult_top #(
        .A_DATA_WIDTH (HIDDEN_WEIGHT_WIDTH),
        .B_DATA_WIDTH(HIDDEN_PIXEL_WIDTH),
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
    wire logic [HIDDEN_NEURONS_SIZE-1:0][OUTPUT_ACTIVATION_WIDTH -1:0] rerequantize_result;
    logic [HIDDEN_NEURONS_SIZE-1:0][OUTPUT_ACTIVATION_WIDTH -1:0] requantized_result_l; // Hidden Layer + RelU output

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
        .INPUT_SCALE_N(HIDDEN_ACCUM_SCALE), // FIXME::Need to parameterize
        .OUTPUT_SCALE_N(OUTPUT_ACTIVATION_SCALE),
        .ARRAY_HEIGHT(HIDDEN_NEURONS_SIZE),
        .ARRAY_WIDTH(1)
    ) reqquantize_u (
        .arr_in(relu_result),
        .arr_out(rerequantize_result)
    );

    // Latch results after combinational logic from RELU and REQUANTIZE
    always_ff @(posedge clk) begin
        if(hidden_result_valid) begin
            requantized_result_l <= rerequantize_result;
        end
    end

    /***** OUTPUT LAYER *****/
    logic [OUTPUT_OUT_SIZE-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result_l;
    logic [OUTPUT_OUT_SIZE-1:0][OUTPUT_ACCUM_WIDTH -1:0] output_layer_result;
    logic output_go_pulse;
    logic output_idle;
    logic output_result_valid;

    // BRAM reads
    wire [OUTPUT_OUT_SIZE-1:0] output_weights_bram_rd_en;
    wire [OUTPUT_OUT_SIZE-1:0][$clog2(HIDDEN_NEURONS_SIZE)-1:0] output_weights_bram_rd_addr;
    wire [OUTPUT_OUT_SIZE-1:0][OUTPUT_WEIGHT_WIDTH-1:0] output_weights_bram_rd_data;

    wire output_activations_bram_rd_en;
    wire [$clog2(HIDDEN_NEURONS_SIZE)-1:0] output_activations_bram_rd_addr;
    logic [OUTPUT_ACTIVATION_WIDTH-1:0] output_activations_bram_rd_data;

    // Assign activation reads from RELU flops (simulate BRAM reads)
    always_ff @(posedge clk) begin
        output_activations_bram_rd_data <= output_activations_bram_rd_en ? requantized_result_l[output_activations_bram_rd_addr] : 'd0;
    end

    always_ff @(posedge clk) begin
        if(output_result_valid)
            output_layer_result_l <= output_layer_result;
    end

    matrix_mult_top #(
        .A_DATA_WIDTH (OUTPUT_WEIGHT_WIDTH), // Weights
        .B_DATA_WIDTH(OUTPUT_ACTIVATION_WIDTH), // Activations (Hidden requantized)
        .ACC_WIDTH  (OUTPUT_ACCUM_WIDTH), // Accumulator
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
    logic argmax_go;
    logic argmax_output_aggregate_idle;
    logic [$clog2(OUTPUT_OUT_SIZE)-1:0] argmax_layer_output_l;
    logic [$clog2(OUTPUT_OUT_SIZE)-1:0] argmax_idx_out;

    assign argmax_output_aggregate_idle = ~argmax_go && ~output_result_valid && output_idle;

    // Control argmax go/idle abstractly
    // One cycle after output done sample the idx_out
    // This is done to help meet timing and break combinational path
    always_ff @(posedge clk) begin
        if(output_result_valid) begin
            argmax_go <= 1'b1;
        end else if(argmax_go == 1'b1) begin
            argmax_go <= 1'b0;
        end
    end

    // Combinational
    argmax #(
        .SIZE(OUTPUT_OUT_SIZE),
        .WIDTH(OUTPUT_ACCUM_WIDTH)
    ) argmax (
        .inputs(output_layer_result_l),
        .index_of_max(argmax_idx_out)
    );

    always_ff @(posedge clk) begin
        if(argmax_go) begin
            argmax_layer_output_l <= argmax_idx_out;
        end
    end

    assign predicted_result_out = {12'b0, argmax_layer_output_l};

    /**** FSM CONTROL ****/
    pipe_control_fsm pipe_controller (
        .clk(clk),

        .compute_go(matrix_control_in[0]),
        .compute_idle(matrix_status_out[0]),

        .hidden_go_pulse(hidden_go_pulse),
        .hidden_idle(hidden_idle),

        .output_go_pulse(output_go_pulse),
        .output_idle(argmax_output_aggregate_idle) // After argmax finished (one cycle more)
    );

    // Hidden Weights
    bram_wrapper #(
        .N(HIDDEN_NEURONS_SIZE), // Number of BRAMS
        .BRAM_SIZE(HIDDEN_ACTIVATION_SIZE), // Per BRAM size
        .DATA_WIDTH(HIDDEN_WEIGHT_WIDTH),
        .OUTDATA_WIDTH(HIDDEN_WEIGHT_WIDTH),
        .SIGN_EXTEND(1),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX({WEIGHTS_DIR, "hidden"})
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
        .BRAM_SIZE(HIDDEN_ACTIVATION_BRAM_SIZE), // 2 pixels wide 
        .DATA_WIDTH(HIDDEN_PIXEL_BRAM_WIDTH), // 2 pixels wide
        .OUTDATA_WIDTH(HIDDEN_WEIGHT_WIDTH), // Read two pixels at once
        .SIGN_EXTEND(0),
        .PRELOAD(0),
        .LOAD_FILE_PREFIX("")
    ) pixel_bram_u (
        .clk(clk),
        .r_en(hidden_pixel_bram_rd_en),
        .r_addr(converted_pixel_bram_rd_addr),
        .r_data(bram_pixel_bram_rd_data),

        .w_en(pixel_wr_en),
        .w_addr(pixel_wr_address[$clog2(HIDDEN_ACTIVATION_BRAM_SIZE)-1:0]),
        .w_data(pixel_wr_data)
    );

    // Output Weights
    bram_wrapper #(
        .N(OUTPUT_OUT_SIZE),
        .BRAM_SIZE(HIDDEN_NEURONS_SIZE), // Per BRAM 
        .DATA_WIDTH(OUTPUT_WEIGHT_WIDTH),
        .OUTDATA_WIDTH(OUTPUT_WEIGHT_WIDTH),
        .SIGN_EXTEND(1),
        .PRELOAD(1),
        .LOAD_FILE_PREFIX({WEIGHTS_DIR, "output"})
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
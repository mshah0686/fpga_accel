package pipe_params;

    /* MATRIX */
    // PIXELS
    localparam HIDDEN_PIXEL_WIDTH = 8;
    localparam HIDDEN_ACTIVATION_SIZE = 28 * 28; // Flattened pixels

    // HIDDEN
    localparam HIDDEN_NEURONS_SIZE = 16;
    localparam HIDDEN_WEIGHT_WIDTH = 16;
    localparam HIDDEN_ACCUM_WIDTH = 32;

    // OUTPUT
    localparam OUTPUT_WEIGHT_WIDTH = 16;
    localparam OUTPUT_ACCUM_WIDTH = 32;
    
    localparam OUTPUT_ACTIVATION_SIZE = 16;
    localparam OUTPUT_ACTIVATION_WIDTH = 16;
    localparam OUTPUT_OUT_SIZE = 10;

    // QUANTIZATIONS
    localparam PIXEL_SCALE = 8; // 2**8
    localparam HIDDEN_WEIGHT_SCALE = 13; // Q3.13
    localparam HIDDEN_ACCUM_SCALE = 21; // Q11.21
    localparam OUTPUT_WEIGHT_SCALE = 13; // Q3.13
    localparam OUTPUT_ACTIVATION_SCALE = 8; // Q8.8 (requantized)
    localparam OUTPUT_ACCUM_SCALE = 21; // Q11.21

endpackage
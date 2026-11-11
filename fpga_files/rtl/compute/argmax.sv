// Module to choose from SIZE inputs
// Output index with maximum

module argmax #(
    parameter SIZE = 10,
    parameter WIDTH = 32,

    localparam SIZE_WIDTH = $clog2(SIZE)
) (
    input clk,

    input go_pulse,
    output logic idle,

    input [SIZE -1: 0][WIDTH-1:0] inputs,

    output logic result_valid,
    output [SIZE_WIDTH-1:0] index_of_max
);
    // Track stage
    logic stage_1;
    logic compute_busy;

    always_ff @(posedge clk) begin
        if(go_pulse) begin
            compute_busy <= 1'b1;
            stage_1 <= 1'b1;
        end

        if(stage_1 == 1'b1) begin
            compute_busy <= 1'b0;
            stage_1 <= 1'b0;
        end
    end

    assign idle = ~compute_busy;


    always_ff @(posedge clk) begin
        if(go_pulse) begin
            max_idx_half_q <= max_idx_half;
            max_value_half_q <= max_value_half;
        end
    end

    // First half - calculate
    logic [SIZE_WIDTH-1:0] max_idx_half[2];
    logic signed [WIDTH-1:0] max_value_half[2];
    // Flops to save first stage
    logic [SIZE_WIDTH-1:0] max_idx_half_q[2];
    logic signed [WIDTH-1:0] max_value_half_q[2];
    
    integer i;
    always_comb begin
        max_value_half[0] = inputs[0];
        max_idx_half[0] = 0;
        for(i = 0; i < SIZE/2; i++) begin
            if($signed(inputs[i]) > max_value_half[0]) begin
                max_value_half[0] = $signed(inputs[i]);
                max_idx_half[0] = i[SIZE_WIDTH-1:0];
            end
        end

        max_value_half[1] = inputs[5];
        max_idx_half[1] = 5;
        for(i = SIZE/2; i < SIZE; i++) begin
            if($signed(inputs[i]) > max_value_half[1]) begin
                max_value_half[1] = $signed(inputs[i]);
                max_idx_half[1] = i[SIZE_WIDTH-1:0];
            end
        end
    end

    // Find greater of two halves
    assign index_of_max = (max_value_half_q[0] >= max_value_half_q[1]) ? max_idx_half_q[0] : max_idx_half_q[1];
    assign result_valid = (stage_1 == 1'b1);

endmodule 
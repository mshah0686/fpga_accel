// MAC implementation block

module mac #(
    parameter ACC_WIDTH = 24,
    parameter D_WIDTH = 8
)
(
    input clk,
    input valid, // Enable compute
    input clear, // Clear values
    input [D_WIDTH -1:0] A,
    input [D_WIDTH-1:0] B,

    output [ACC_WIDTH-1:0] acc_out
);

    // If clear and valid on same cycle, only A*B accumulated
    // If clear and no valid, acc cleared
    // If only valid, then A*B added to accumulator

    wire[(D_WIDTH*2)-1:0] mult;
    wire[ACC_WIDTH -1 : 0] mult_extended;
    wire[ACC_WIDTH-1:0] acc_next;

    reg [ACC_WIDTH-1:0] acc = {ACC_WIDTH{1'b0}};


    assign mult = A * B; // Multiply
    assign mult_extended = {{(ACC_WIDTH - (2*D_WIDTH)){1'b0}}, mult};
    assign acc_next = clear ? mult_extended : mult_extended + acc; // Add


    always @(posedge clk) begin
        if(valid) begin
            acc <= acc_next; // Assign to next if valid
        end else if (clear) begin
            acc <= {ACC_WIDTH{1'b0}}; // Clear if only clear
        end
    end

    assign acc_out = acc;

endmodule 
module segment_display
(
    input clk,
    input [3:0] count,

    output reg A,
    output reg B, 
    output reg C,
    output reg D,
    output reg E,
    output reg F,
    output reg G
);

    // reg [3:0] display_latch = 4'b0;

    // // Latch on valid
    // always @(posedge clk) begin
    //     if(valid) begin
    //         display_latch <= count;
    //     end
    // end


    always @(*) begin
        // Default value
        A = 1'b1;B=1'b1; C=1'b1; D=1'b1; E=1'b1; F=1'b1; G=1'b1;
        case(count)
            4'd0: begin
                A = 1'b0; B = 1'b0; C =1'b0; D = 1'b0; E = 1'b0; F = 1'b0;
            end
            4'd1: begin
                B = 1'b0; C = 1'b0;
            end
            4'd2: begin
                A = 1'b0; B = 1'b0; G =1'b0; E = 1'b0; D = 1'b0;
            end
            4'd3: begin
                A = 1'b0; B = 1'b0; C =1'b0; D = 1'b0; G = 1'b0;
            end
            4'd4: begin
                B = 1'b0; C =1'b0; F = 1'b0; G = 1'b0;
            end
            4'd5: begin
                A = 1'b0; C =1'b0; D = 1'b0; F = 1'b0; G = 1'b0;
            end
            4'd6: begin
                A = 1'b0; C =1'b0; D = 1'b0; E = 1'b0; F = 1'b0; G = 1'b0;
            end
            4'd7: begin
                A = 1'b0; B = 1'b0; C =1'b0;
            end
            4'd8: begin
                A = 1'b0; B = 1'b0; C =1'b0; D = 1'b0; E = 1'b0; F = 1'b0; G = 1'b0;
            end
            4'd9: begin
                A = 1'b0; B = 1'b0; C =1'b0; D = 1'b0; F = 1'b0; G = 1'b0;
            end
            default : begin
                A = 1'b0; B = 1'b0; C =1'b0; D = 1'b0; E = 1'b0; F = 1'b0;
            end
        endcase

    end


endmodule
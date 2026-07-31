module bin2gray #(
    parameter SIZE=4
)
(
    input [SIZE-1:0] bin_in,
    output [SIZE-1:0] gray_out
);

    assign gray_out = (bin_in >> 1) ^ bin_in;

endmodule
module bin2gray #(
    parameter SIZE=4
)
(
    input [SIZE:0] bin_in,
    output [SIZE:0] gray_out
);

    assign gray_out = (bin_in >> 1) ^ bin_in;

endmodule
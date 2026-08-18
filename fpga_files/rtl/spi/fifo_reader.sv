// Read when SPI output fifo is not empty
// Output to display and UART data being read
// Read whenever UART is ready and fifo is empty
// Send with valids to outputs
module fifo_reader #(
    parameter DATA_WIDTH = 8
) (
    input clk,

    // FIFO
    input fifo_empty,
    input [DATA_WIDTH-1:0] r_data,
    output r_en,

    // UART ready
    input downstream_ready,

    // Data out
    output reg data_valid,
    output reg [DATA_WIDTH-1:0] data,

    output reg [3:0] led_dbg
);
    assign r_en = downstream_ready & ~fifo_empty;
    // Save fifo value
    reg [DATA_WIDTH-1:0] data_latch;

    always @(posedge clk) begin
        if(r_en) begin
            data <= r_data;
            data_valid <= 1'b1;
            led_dbg <= r_data[3:0];
        end else begin
            data_valid <= 1'b0;
        end
    end

endmodule
module spi_peripheral
#( parameter DATA_WIDTH=8)
(
    input spi_clk,
    input spi_data,
    input spi_cs,

    output [DATA_WIDTH-1:0] data_out,
    output data_valid
);

parameter DATA_COUNTER_WIDTH = $clog2(DATA_WIDTH);

// Latch input data
reg [DATA_WIDTH-1:0] data_q = {DATA_WIDTH{1'b0}};

// Count input bits
reg [DATA_COUNTER_WIDTH - 1 : 0] recieved_count = 0;

// Latch data valid
reg valid_q;

// Flag for data recieved
wire recieved_all_data_flag;
assign recieved_all_data_flag = recieved_count == (DATA_WIDTH -1);

// Latch SPI data
always @(posedge spi_clk) begin
    if(~spi_cs) begin
        data_q <= {data_q[DATA_WIDTH-2:0], spi_data};
    end

    if(~spi_cs) begin
        recieved_count <= recieved_all_data_flag ? {DATA_COUNTER_WIDTH{1'b0}} : recieved_count + 1;
    end

    if(recieved_all_data_flag && ~spi_cs) begin
        valid_q <= 1'b1;
    end else begin
        valid_q <= 1'b0;
    end
end

// Output assignment
assign data_out = valid_q ? data_q : {DATA_WIDTH{1'b0}};
assign data_valid = valid_q;

endmodule
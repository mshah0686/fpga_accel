module spi_rx
#( parameter DATA_WIDTH=32)
(
    input spi_clk,
    input spi_pico, // ucontroller -> FPGA
    input spi_cs,

    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_valid_flag,
    output [3:0] led_dbg,
    output [3:0] pwd_debug // SHIFT_REGISTER_VALUE
);

// Count data recieved
parameter DATA_COUNTER_WIDTH = $clog2(DATA_WIDTH);

// Shift register for input data
reg [DATA_WIDTH-1:0] shift_reg = {DATA_WIDTH{1'b0}};

// Count recieved data
reg [DATA_COUNTER_WIDTH - 1 : 0] recieved_count = 0;

// On last transaction
wire last_txn_flag;
assign last_txn_flag = ({1'b0, recieved_count} == (DATA_WIDTH -1));

// Latch SPI data
always @(posedge spi_clk) begin
    // Generally this flop will only enter when spi_cs is low as per SPI interface
    if(last_txn_flag) begin
        // No more clks after this until next cycle!
        shift_reg <= {DATA_WIDTH{1'b0}};
        data_out <=  {shift_reg[DATA_WIDTH-2:0], spi_pico};
        data_valid_flag <= 1'b1;
        recieved_count <= 'b0;
    end else if (~spi_cs) begin
        shift_reg <= {shift_reg[DATA_WIDTH-2:0], spi_pico};
        recieved_count <= recieved_count + 1;
        data_valid_flag <= 1'b0;
    end
end


/*** DEBUG ***/
assign led_dbg = shift_reg[3:0];
assign pwd_debug = {last_txn_flag, data_valid_flag, spi_clk, 1'b0};

endmodule
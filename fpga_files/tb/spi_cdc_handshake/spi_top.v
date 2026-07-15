module spi_top_wrap 
#(parameter DATA_WIDTH=8)
(
    // SPI control interfaces
    input spi_clk,
    input spi_data,
    input spi_cs,

    // System control interfaces
    input clk,
    input system_ready,
    output data_valid,
    output [DATA_WIDTH -1:0] data_out
);

    wire [DATA_WIDTH-1:0] spi_data_out;
    wire spi_data_valid;

    spi_peripheral #(.DATA_WIDTH(DATA_WIDTH)) spi_peripheral_u (
        // External SPI input
        .spi_clk(spi_clk),
        .spi_data(spi_data),
        .spi_cs(spi_cs),

        // Data out
        .data_out(spi_data_out),
        .data_valid_flag(spi_data_valid),
        
        // DBG
        .led_dbg(),
        .pwd_debug()
    );


    spi_rx_sync #(.DATA_WIDTH(DATA_WIDTH)) spi_rx_sync_u (
        .system_clk(clk),
        // To TOP WRAPmshah99
        
        .data_out(data_out),
        .system_ready(system_ready),
        .data_valid(data_valid),

        // Input from SPI perpheral
        .spi_data_in(spi_data_out),
        .spi_data_valid(spi_data_valid),
        .led_dbg()
    );


endmodule
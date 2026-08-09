// Handle RX and TX
//  - Receive SPI packets, CDC into the system clock, decode to the RAL request bus
//  - Accept RAL read data and stream it back out over SPI TX

`include "fpga_types.v"

module spi_top (
    input clk,                       // system clock

    // SPI physical interface
    input  spi_sck,                  // SPI serial clock
    input  spi_pico,                 // controller -> FPGA
    input  spi_cs,                   // chip select (active low)
    output spi_poci,                 // FPGA -> controller

    // Decoded packet out to register model (RAL)
    output                   ral_req_valid,
    output                   ral_req_wr_en,
    output [`ADDR_WIDTH-1:0] ral_req_addr,
    output [`DATA_WIDTH-1:0] ral_req_data,

    // Read data in from register model -> TX FIFO
    input                    rd_fifo_wr_en,
    input  [`DATA_WIDTH-1:0] rd_fifo_wr_data,

    // DBG
    output [3:0] dbg
);

    // RX -> SPI read data
    wire [`TXN_WIDTH-1:0] spi_rx_data;         // SPI clock domain
    wire                  spi_rx_valid;

    // RX -> Synced data
    wire [`TXN_WIDTH-1:0] spi_rx_synced_data;  // system clock domain
    wire                  spi_rx_synced_valid;

    // TX -> Read from fifo
    wire [`DATA_WIDTH-1:0] rd_fifo_rd_data;
    wire                   rd_fifo_rd_en;
    wire                   rd_fifo_empty;

    // Receiver (SPI clock domain)
    spi_rx #(.DATA_WIDTH(`TXN_WIDTH))
    spi_rx_u (
        // INPUT
        .spi_clk(spi_sck),
        .spi_pico(spi_pico),
        .spi_cs(spi_cs),

        // OUTPUT
        .data_out(spi_rx_data),
        .data_valid_flag(spi_rx_valid),

        // DBG
        .pwd_debug(),
        .led_dbg()
    );

    // CDC from SPI clock to system clock
    spi_rx_sync #(.DATA_WIDTH(`TXN_WIDTH))
    spi_rx_sync_u (
        .system_clk(clk),

        // Inputs
        .spi_data_in(spi_rx_data),
        .spi_data_valid(spi_rx_valid),

        // Outputs
        .data_out(spi_rx_synced_data),
        .data_valid(spi_rx_synced_valid),
        .system_ready(1'b1),

        // DBG
        .dbg()
    );

    // Decode packet into RAL request bus
    packet_decoder packet_decoder_u (
        .clk(clk),

        // INPUT
        .packet_valid(spi_rx_synced_valid),
        .packet_data(spi_rx_synced_data),

        // OUTPUT RAL CONTROL
        .out_valid(ral_req_valid),
        .out_wr_en(ral_req_wr_en),
        .out_addr(ral_req_addr),
        .out_data(ral_req_data)
    );

    // TX read-data FIFO (write: system clock, read: SPI clock)
    async_fifo #(
        .DEPTH(2),
        .DATA_WIDTH(`DATA_WIDTH)
    ) rd_out_fifo_u (
        .w_en(rd_fifo_wr_en),
        .w_data(rd_fifo_wr_data),
        .w_clk(clk),
        .fifo_full(),

        .r_en(rd_fifo_rd_en),
        .r_data(rd_fifo_rd_data),
        .r_clk(~spi_sck), // Flip clock since SPI drive on negedge and latch on posedge
        .fifo_empty(rd_fifo_empty),

        .led_dbg_read(),
        .led_dbg_write()
    );

    // SPI TX: stream FIFO data back out over POCI
    // Note -> Latches here operate on negedge
    spi_tx #(
        .TXN_WIDTH(`TXN_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) spi_tx_u (
        .spi_clk(spi_sck),
        .spi_poci(spi_poci),
        .spi_cs(spi_cs),

        // FIFO connection
        .fifo_read_data_in(rd_fifo_rd_data),
        .fifo_empty_in(rd_fifo_empty),
        .r_en_out(rd_fifo_rd_en),

        .dbg(dbg)
    );

endmodule

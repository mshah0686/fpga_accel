module spi_rx_sync
#( parameter DATA_WIDTH=8)
(
    input system_clk,
    output [DATA_WIDTH -1:0] data_out,
    output data_valid,
    input system_ready,
    
    // SPI input
    // CDC!!!
    input [DATA_WIDTH-1:0] spi_data_in,
    input spi_data_valid,

    // DEBGUG
    output [3:0] led_dbg
)

    wire [DATA_WIDTH-1:0] sync_data_out;
    wire sync_valid_out;

    // Sync the inputs accross clocks
    sync_flops #(.SIZE(8)) data_sync (
        .clk(system_clk), 
        .in(spi_data_in),
        .out(sync_data_out)
    );
    // Sync valid signal accross clocks
    sync_flops #(.SIZE(1)) valid_sync (
        .clk(system_clk), 
        .in(spi_data_valid),
        .out(sync_valid_out)
    );

    // Edge detection on on valid signal
    // Valid signal on rising edge of spi_valid
    reg valid_q = 1'b0;
    wire valid_rising_edge_flag = ~valid_q && sync_valid_out;
    always @(posedge clk) begin
        valid_q <= sync_valid_out;
    end

    // Send data downstream
    /* Send data downstream:
        - When we see valid pulse, hold valid until handshake
        - Clear valid after handshake until next pulse
    */
    wire downstream_handshake = data_valid && system_ready;
    reg downstream_valid_q = 1'b0;
    always @(posedge clk) begin
        if(downstream_handshake) begin
            downstream_valid_q <= 1'b0;
        end else if (valid_rising_edge_flag) begin
            // 1 cycle latency - can be optimized to assert ready on flag cycle but it is okay for now
            downstream_valid_q <= 1'b1;
        end
    end

    assign data_out = sync_data_out;
    assign data_valid = downstream_valid_q;

endmodule
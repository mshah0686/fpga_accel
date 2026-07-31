
// Decode SPI commands to downstream
`include "fpga_types.v"
/*
4 Byte transactions:
[CMD: 8bit][ADDR: 8bit][DATA: 16 bits]

CMND:
    0x0 NOP
    0x1 WRITE
    0x2 READ

ADDR:
    0x0 NOP
    0x1 TIMER

TIMER: DATA (16 bits)
    WR
    0x0 CLEAR TIMER
    0x1 START TIMER
    0x2 STOP TIMER
    
    RD
    {timer_en, timer_count}
*/

module register_model (
    input clk,

    // Packet inputs
    input in_valid,
    input in_wr_en,
    input [`DATA_WIDTH-1:0] in_data,
    input [`ADDR_WIDTH-1:0] in_addr,

    output reg out_timer_clear,
    output reg out_timer_start,
    output reg out_timer_stop,

    // Peripheral input data
    input in_timer_en,
    input [7:0] in_timer_count,

    // Read data output to fifo
    output reg out_rd_valid,
    output reg [`DATA_WIDTH-1:0] out_rd_data,

    // DBG
    output [3:0] dbg
);

    always @(posedge clk) begin
        // Default 0
        out_rd_valid      <= 1'b0;
        out_timer_clear   <= 1'b0;
        out_timer_start   <= 1'b0;
        out_timer_stop    <= 1'b0;

        if (in_valid) begin
            if (in_wr_en) begin
                if (in_addr == `TIMER_ADDR) begin
                    out_timer_clear <= (in_data == `TIMER_CLEAR);
                    out_timer_start <= (in_data == `TIMER_START);
                    out_timer_stop <= (in_data == `TIMER_STOP);
                end
            end else begin
                if (in_addr == `TIMER_ADDR) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data  <= {7'd0, in_timer_en, in_timer_count};
                end
            end
        end
    end

    assign dbg = {out_timer_clear, out_timer_start, out_timer_stop, out_rd_valid};

endmodule
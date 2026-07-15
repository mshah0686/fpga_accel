// Decode SPI commands to downstream
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

TIMER: DATA
    0x0 CLEAR TIMER
    0x1 START TIMER
    0x2 STOP TIMER
    //Read pending
*/

module packet_decoder (
    input clk,

    // Packet inputs
    input packet_valid,
    input [31:0] packet_data,

    // Packet outputs
    output reg timer_clear,
    output reg timer_start,
    output reg timer_stop
);
    wire [CMD_WIDTH-1:0] cmd;
    wire [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] data;

    assign {cmd, addr, data} = packet_data;

    // Simple decoder can be done combinationally
    // Issue pulse signal tied to valid pulse input to the timer
    always_comb begin
        // Initial drive to prevent flop infer
        timer_clear = 1'b0;
        timer_start = 1'b0;
        timer_stop = 1'b0;

        if(packet_valid && (addr == TIMER_ADDR)) begin
            if (cmd == CMD_WRITE) begin
                if(data == TIMER_CLEAR) begin
                    timer_clear = 1'b1;
                end else if(data == TIMER_START) begin
                    timer_start = 1'b1;
                end else if(data == TIMER_STOP) begin
                    timer_stop = 1'b1;
                end
            end
        end

    end


endmodule
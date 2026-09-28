// Decode SPI commands to downstream
`include "fpga_types.sv"
/*
    Simple logic to decode the packet into register interface
*/
module packet_decoder (
    input clk,

    // Packet inputs
    input packet_valid,
    input [31:0] packet_data,

    // Output RD/WR
    output out_valid,
    output out_wr_en,
    output [`TAG_WIDTH-1:0] out_tag,
    output [`ADDR_WIDTH-1:0] out_addr,
    output [`DATA_WIDTH-1:0] out_data
);

    wire [`CMD_WIDTH-1:0] cmd;
    wire [`TAG_WIDTH-1:0] tag;
    wire [`ADDR_WIDTH-1:0] addr;
    wire [`DATA_WIDTH-1:0] data;

    assign {cmd, tag, addr, data} = packet_data;
    
    // Assign rd/wr
    assign out_valid = packet_valid && (cmd != `CMD_NOP); // Drop NOPs here
    assign out_wr_en = packet_valid  && (cmd == `CMD_WRITE) ? 1'b1 : 1'b0;
    assign out_addr = addr;
    assign out_data = data;
    assign out_tag = tag;

endmodule
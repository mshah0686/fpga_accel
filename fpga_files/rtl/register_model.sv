
// Decode SPI commands to downstream
`include "fpga_types.sv"
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

module register_model 
#(
    parameter MATRIX_D_WIDTH = 8,
    parameter MATRIX_ACC_WIDTH = 16
)
(
    input clk,

    // Packet inputs
    input in_valid,
    input in_wr_en,
    input [`DATA_WIDTH-1:0] in_data,
    input [`ADDR_WIDTH-1:0] in_addr,


    // TIMER CONTROL
    output reg out_timer_clear,
    output reg out_timer_start,
    output reg out_timer_stop,

    input in_timer_en,
    input [7:0] in_timer_count,

    // MULT CONTROL
    output reg [1:0][1:0][MATRIX_D_WIDTH-1:0] a_matrix,
    output reg [1:0][1:0][MATRIX_D_WIDTH-1:0] b_matrix,
    output reg [15:0] matrix_control_write,

    input [1:0][1:0][MATRIX_ACC_WIDTH-1:0] matrix_result,
    input [15:0] matrix_control,

    // Read data output to fifo
    output reg out_rd_valid,
    output reg [`DATA_WIDTH-1:0] out_rd_data,

    // DBG
    output [3:0] dbg
);

    // Peripheral TAG -> then addr split after
    wire [`ADDR_PERIF_TAG_WIDTH-1:0] peripheral_tag = in_addr[`ADDR_PERIF_TAG_WIDTH - 1:0]; // LSB
    wire [`ADDR_REG_WIDTH-1:0] peripheral_reg_addr = in_addr[`ADDR_WIDTH-1:`ADDR_PERIF_TAG_WIDTH]; // MSB

    // ---------------- TIMER CONTROL (write, one-cycle pulse outputs) ----------------
    always @(posedge clk) begin
        out_timer_clear <= 1'b0;
        out_timer_start <= 1'b0;
        out_timer_stop  <= 1'b0;

        if (in_valid && in_wr_en && peripheral_tag == `TIMER_TAG) begin
            // Only one register so doesn't really matter
            out_timer_clear <= (in_data == `TIMER_CLEAR);
            out_timer_start <= (in_data == `TIMER_START);
            out_timer_stop  <= (in_data == `TIMER_STOP);
        end
    end

    // ---------------- MATRIX REGISTER WRITE (held) ----------------
    // A/B operand elements and the control register hold until overwritten.
    wire [`MATRIX_TYPE_WIDTH-1:0] matrix_type;
    wire [`MATRIX_IDX_WIDTH-1:0] matrix_row_idx;
    wire [`MATRIX_IDX_WIDTH-1:0] matrix_col_idx;
    wire [`MATRIX_RESERVED_WIDTH-1:0] matrix_reserved;

    assign {matrix_type, matrix_row_idx, matrix_col_idx, matrix_reserved} = peripheral_reg_addr;
    always @(posedge clk) begin
        matrix_control_write <= 16'd0; // Only one cycle write
        if (in_valid && in_wr_en && peripheral_tag == `MATRIX_TAG) begin
            if (matrix_type == `MATRIX_A) begin
                a_matrix[matrix_row_idx][matrix_col_idx] <= in_data[MATRIX_D_WIDTH-1:0];
            end else if (matrix_type == `MATRIX_B) begin
                b_matrix[matrix_row_idx][matrix_col_idx] <= in_data[MATRIX_D_WIDTH-1:0];
            end else if (matrix_type == `MATRIX_CONTROL) begin
                matrix_control_write <= in_data;
            end
        end
    end

    // ---------------- READ PATH (timer + matrix C + status) ----------------
    // Sole driver of out_rd_valid/out_rd_data.
    always @(posedge clk) begin
        out_rd_valid <= 1'b0;

        if (in_valid && !in_wr_en) begin
            if (peripheral_tag == `TIMER_TAG) begin
                out_rd_valid <= 1'b1;
                out_rd_data  <= {7'd0, in_timer_en, in_timer_count};
            end else if (peripheral_tag == `MATRIX_TAG) begin
                if (matrix_type == `MATRIX_A) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= {8'd0, a_matrix[matrix_row_idx][matrix_col_idx]}; // FIXME::Need to parameterize this based on data size
                end else if (matrix_type == `MATRIX_B) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= {8'd0, b_matrix[matrix_row_idx][matrix_col_idx]};
                end else if (matrix_type == `MATRIX_CONTROL) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_control;
                end else if (matrix_type == `MATRIX_C) begin
                    out_rd_valid <= 1'b1;
                    out_rd_data <= matrix_result[matrix_row_idx][matrix_col_idx];
                end
            end
        end
    end

    assign dbg = {out_timer_clear, out_timer_start, out_timer_stop, out_rd_valid};

endmodule
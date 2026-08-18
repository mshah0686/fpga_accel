module spi_tx #( 
    parameter TXN_WIDTH=32, 
    parameter DATA_WIDTH=16)
(
    input spi_clk,
    output spi_poci, // FPGA -> ucontroller
    input spi_cs,

    // Read data
    input [DATA_WIDTH-1 : 0] fifo_read_data_in,
    input fifo_empty_in,
    output r_en_out,

    output [3:0] dbg
);

    localparam INIT= 2'd0, WAIT_TO_SEND = 2'd1, SEND = 2'd2, SKIP = 2'd3;

    reg [1:0] next_state;
    reg [1:0] current_state;
    reg [DATA_WIDTH-1:0] send_data_shift_reg;
    reg [$clog2(TXN_WIDTH) - 1:0] cycle_count;
    localparam [4:0] LAST_TXN_CYCLE = 5'(TXN_WIDTH - 1);

    always @(negedge spi_clk) begin
        current_state <= next_state;
    end

    always @(negedge spi_clk) begin
        case(current_state)
            INIT : begin
                // Read data from fifo (r_en asserted in this stage if fifo not empty)
                send_data_shift_reg <= fifo_read_data_in;
            end

            WAIT_TO_SEND : begin
                // Don't need to latch anything
            end

            SEND : begin
                // Shift and send
                send_data_shift_reg <= send_data_shift_reg << 1;
            end

            SKIP : begin
                // Don't need to latch anything
            end 
        endcase
    end


    always @(*) begin
        next_state = INIT;
        case (current_state)
            INIT : begin
                if(~fifo_empty_in && cycle_count == 5'd1) begin
                    next_state = WAIT_TO_SEND;
                end else if(cycle_count == 5'd2) begin
                    next_state = SKIP;
                end else begin
                    next_state = INIT;
                end
            end

            WAIT_TO_SEND : begin // Wait to send last 16 bits
                if(cycle_count == (DATA_WIDTH-1)) begin
                    next_state = SEND;
                end else begin
                    next_state = WAIT_TO_SEND;
                end
            end

            SEND : begin
                if(cycle_count == LAST_TXN_CYCLE) begin // Finish sending
                    next_state = INIT;
                end else begin
                    next_state = SEND;
                end
            end

            SKIP : begin
                if(cycle_count == LAST_TXN_CYCLE) begin // Skip TXN if nothing to send
                    next_state = INIT;
                end else begin
                    next_state = SKIP;
                end
            end
            default:
                next_state = INIT;
        endcase
    end

    always @(negedge spi_clk) begin
        cycle_count <= cycle_count == LAST_TXN_CYCLE ? 'b0 : cycle_count + 'b1; // Count the cycles in txn
    end

    // r_en when in init state and data to read - latch in that cycle as data will be valid that cycle
    assign r_en_out = (current_state == INIT) & ~fifo_empty_in;
    assign spi_poci = (current_state == SKIP) ? 1'b1 : (current_state == INIT || current_state == WAIT_TO_SEND) ? 1'b0 : send_data_shift_reg[DATA_WIDTH - 1];

    assign dbg = {fifo_empty_in, 1'b0, current_state};
endmodule
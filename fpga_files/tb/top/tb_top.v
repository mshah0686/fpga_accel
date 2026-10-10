`timescale 1ns/1ps
// Full-chip testbench: drives the inference through the SPI pins only, no
// hierarchical pokes into the DUT. Checks the pixel stimulus and the final
// argmax; the intermediate taps are tb_pipe's job.
module tb_top;

    import fpga_params::*;
    import pipe_params::*;

    parameter real SYS_CLK_PERIOD = 1000.0 / 450.0;  // 450 MHz system clock
    parameter real SPI_CLK_PERIOD = 1000 / 13; // 13 Hz

    // 392 pixel writes + GO + a handful of read pairs, each transaction
    // 32 * SPI_CLK_PERIOD ~= 2.5 us. Round well up.
    parameter real TIMEOUT_NS = 3000000;

    localparam ACTIVATIONS = HIDDEN_ACTIVATION_SIZE;
    localparam PIX_WIDTH   = HIDDEN_PIXEL_WIDTH;
    localparam PIXEL_WRITES = ACTIVATIONS / PIXEL_PER_WRITE;

    localparam [ADDR_WIDTH-1:0] MATRIX_STATUS_ADDR = 'd0;  // control on write
    localparam [ADDR_WIDTH-1:0] MATRIX_RESULT_ADDR = 'd1;

    // One NOP is normally enough to shift a response back out; allow a couple
    // more so a slow FIFO pointer sync doesn't look like a functional failure.
    localparam MAX_RD_NOPS = 4;
    localparam MAX_STATUS_POLLS = 1000;

    reg sys_clk;
    reg spi_pico;
    reg spi_cs;

    wire spi_poci;
    reg spi_clk_ref;
    wire spi_sck = spi_cs ? 1'b0 : spi_clk_ref;

    top uut (
        .i_clk     (sys_clk),

        .io_PMOD_1 (spi_sck),   // SPI clk
        .io_PMOD_2 (spi_pico),  // SPI PICO data
        .io_PMOD_3 (spi_cs),    // SPI cs (active low)
        .io_PMOD_4 (spi_poci)   // SPI POCI data
    );

    initial begin
        sys_clk = 1'b0;
        forever #(SYS_CLK_PERIOD/2.0) sys_clk = ~sys_clk;
    end

    initial begin
        spi_clk_ref <= 1'b0;
        forever #(SPI_CLK_PERIOD/2.0) spi_clk_ref <= ~spi_clk_ref;
    end

    task automatic send_spi(
        input [CMD_WIDTH-1:0]   cmd,
        input [TAG_WIDTH-1:0]  tag,
        input [ADDR_WIDTH-1:0]  addr,
        input [DATA_WIDTH-1:0]  data
    );
        reg [TXN_WIDTH-1:0] word;
        integer i;
        begin
            word = {cmd, 2'b0, tag, addr, data};

            $display("SPI - SEND %0x: cmd=%0x tag=%0x addr=%0x data=%0x", word, cmd, tag, addr, data);

            // Open the gate on a negedge: SCK is already low here
            @(negedge spi_clk_ref);
            spi_cs = 1'b0;

            for (i = TXN_WIDTH-1; i >= 0; i = i - 1) begin
                spi_pico = word[i];
                @(posedge spi_clk_ref);  // DUT samples the bit here
                @(negedge spi_clk_ref);  // safe point to change it
            end

            spi_cs   = 1'b1;
            spi_pico = 1'b0;

            // Let the monitor's push and the CDC settle before the caller
            // looks at spi_rd_fifo, and space out back-to-back transactions.
            @(negedge spi_clk_ref);
        end
    endtask

    reg [DATA_WIDTH-1:0] spi_rd_fifo [$];
    reg [TXN_WIDTH-1:0]  spi_rd_capture;

    // spi_tx holds POCI low for the first 16 bits of a response frame and
    // drives it high for the whole frame when it has nothing to send (SKIP),
    // so "top half zero" is what separates a real response from an idle one.
    task automatic spi_rd_monitor();
        forever begin
            @(negedge spi_cs);
            spi_rd_capture = '0;

            while (spi_cs == 1'b0) begin
                @(posedge spi_sck or posedge spi_cs);
                if (spi_cs == 1'b0)
                    spi_rd_capture = {spi_rd_capture[TXN_WIDTH-2:0], spi_poci};
            end

            if (spi_rd_capture[TXN_WIDTH-1 -: DATA_WIDTH] == '0)
                spi_rd_fifo.push_back(spi_rd_capture[DATA_WIDTH-1:0]);
        end
    endtask

    // A read takes two transactions: the READ, then NOPs until the response
    // comes back out on POCI.
    task automatic spi_read(
        input  [TAG_WIDTH-1:0]  tag,
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] data,
        output valid
    );
        integer nops;
        begin
            send_spi(CMD_READ, tag, addr, {DATA_WIDTH{1'b0}});
            send_spi(CMD_NOP, tag, {ADDR_WIDTH{1'b0}}, {DATA_WIDTH{1'b0}});
            if(spi_rd_fifo.size() > 0) begin
                data = spi_rd_fifo.pop_front();
                valid = 1'b1;
            end else begin
                data = 'b0;
                valid = 1'b0;
            end
        end
    endtask

    reg [PIX_WIDTH-1:0] pixels     [0:ACTIVATIONS-1];
    reg [3:0]           exp_argmax [0:0];

    // Run `python3 scripts/model_pipeline/pipeline.py --index N` first: it
    // writes golden_*.hex into fpga_files/golden/ -- the same goldens tb_pipe
    // reads -- so the paths below need the sim run from the fpga_files/ root.
    task load_goldens();
        $readmemh("golden/golden_pixels.hex", pixels);
        $readmemh("golden/golden_argmax.hex", exp_argmax);
    endtask

    // $readmemh on a missing file is only a warning and leaves every array at
    // zero -- an all-zero image still runs and still predicts *something*, so
    // a silent pass is possible. Refuse to run on empty pixels. (argmax is
    // legitimately 0 for one tenth of the images, so it can't be checked here.)
    task check_goldens_loaded();
        integer nonzero;
        nonzero = 0;
        for (int i = 0; i < ACTIVATIONS; i++)
            if (pixels[i] != 0) nonzero++;

        if (nonzero == 0) begin
            $display("Goldens are all zero -- did they load?");
            $display("  $readmemh resolves against the CWD: run via");
            $display("  `cmake --build . --target run_top_tb`, and run");
            $display("  `python3 scripts/model_pipeline/pipeline.py` first.");
            $fatal(1, "empty goldens");
        end
    endtask

    // register_model lands in_data[7:0] at the packet address and in_data[15:8]
    // at address+1, so pixel i goes in the low byte of the write to address i
    // and pixel i+1 in the high byte.
    task automatic write_pixels();
        for (int i = 0; i < ACTIVATIONS; i = i + PIXEL_PER_WRITE) begin
            send_spi(CMD_WRITE, TAG_WIDTH'(PIXEL_TAG), ADDR_WIDTH'(i),
                     {pixels[i+1], pixels[i]});
        end
        $display("[%0t] Wrote %0d pixels in %0d transactions.",
                 $time, ACTIVATIONS, PIXEL_WRITES);
    endtask

    // register_model clears matrix_control_out every cycle it isn't written,
    // so a single write is already the one-cycle GO pulse the FSM wants.
    task automatic write_go();
        send_spi(CMD_WRITE, TAG_WIDTH'(MATRIX_TAG), MATRIX_STATUS_ADDR, 16'h0001);
        $display("[%0t] Wrote GO.", $time);
    endtask

    // Unlike tb_pipe this can't fall through on the pre-GO idle state: the
    // first poll's READ isn't latched by the register model until the end of
    // its transaction, by which point the FSM has long since left IDLE.
    task automatic wait_for_idle();
        reg [DATA_WIDTH-1:0] status;
        reg valid;
        integer polls;
        begin
            polls = 0;
            forever begin
                spi_read(TAG_WIDTH'(MATRIX_TAG), MATRIX_STATUS_ADDR, status, valid);
                polls = polls + 1;
                $display("[%0t]   poll %0d: status=0x%04h (idle=%0b)",
                         $time, polls, status, status[0]);

                if(valid && status[0]) begin
                    break;
                end
            end
            $display("[%0t] Compute idle after %0d poll(s).", $time, polls);
        end
    endtask

    task automatic check_result();
        reg [DATA_WIDTH-1:0] result;
        reg valid;
        begin
            spi_read(TAG_WIDTH'(MATRIX_TAG), MATRIX_RESULT_ADDR, result, valid);
            if (result[3:0] != exp_argmax[0]) begin
                $display("[%0t] FAIL argmax: expected %0d, got %0d (result reg 0x%04h)",
                         $time, exp_argmax[0], result[3:0], result);
                $fatal(1, "argmax mismatch");
            end
            $display("[%0t] PASS argmax %0d (result reg 0x%04h)",
                     $time, result[3:0], result);
        end
    endtask

    // Standalone watchdog so it can't gate the main sequence.
    initial begin
        #TIMEOUT_NS;
        $display("[%0t] FAIL timeout after %0.0f ns.", $time, TIMEOUT_NS);
        $fatal(1, "timeout waiting for the test to finish");
    end

    initial begin
        spi_cs   = 1'b1;  // deasserted
        spi_pico = 1'b0;

        fork
            spi_rd_monitor();
        join_none

        load_goldens();
        check_goldens_loaded();

        write_pixels();
        write_go();
        wait_for_idle();
        check_result();

        $display("[%0t] === TEST PASSED: argmax over SPI matches pipeline.py ===",
                    $time);
        $finish;
    end

endmodule

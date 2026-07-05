module tb_spi_handshake_top (
);

    logic clk = 0; // Starts at 0 automatically

    always begin
        #5 clk = ~clk;
    end

    initial begin
        $dumpfile("waves/sim_waves.vcd");
        $dumpvars();
    end


    // 1. Instantiate your actual SPI RTL here
    reg        rst_n;
    reg        src_valid;
    wire       dest_ready;
    
    // Example connections to your real sub-module
    // spi_cdc_handshake uut (
    //     .clk       (clk),
    //     .rst_n     (rst_n),
    //     .src_valid (src_valid),
    //     .dest_ready(dest_ready)
    // );

    // 2. Drive your test vectors completely inside the module!
    initial begin
        $display("[Verilog TB] Simulation Started.");
        
        // Initialize your signals
        rst_n     = 1'b0;
        src_valid = 1'b0;
        
        // Hold reset for 10 clock ticks
        #10;
        rst_n     = 1'b1;
        $display("[Verilog TB] Released Reset.");
        
        // Wait a bit, then assert a valid signal
        #20;
        src_valid = 1'b1;
        $display("[Verilog TB] Asserted src_valid.");

        // Wait for the hardware to process the handshake
        #50;
        
        // End the simulation. This instantly tells the C++ loop to stop!
        $display("[Verilog TB] Success! Test finished. Stopping simulation.");
        $finish;
    end

endmodule
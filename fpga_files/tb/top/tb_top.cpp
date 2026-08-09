#include <memory>
#include "Vtb_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    // 1. Context and setup
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);

    // 2. Instantiate the top module
    auto dut = std::make_unique<Vtb_top>(contextp.get());

    // 3. Setup Tracing
    Verilated::traceEverOn(true);
    auto tfp = std::make_unique<VerilatedVcdC>();
    dut->trace(tfp.get(), 99);
    tfp->open("waves/tb_top.vcd");

    // 4. Correct Simulation Loop for --timing
    // We let the Verilog code handle the time advancement.
    while (!contextp->gotFinish()) {
        dut->eval();
        tfp->dump(contextp->time());

        // This is the crucial line:
        // We do NOT manually increment time. We ask the model:
        // "When is the next scheduled event?"
        contextp->time(dut->nextTimeSlot());
    }

    tfp->close();
    dut->final();
    return 0;
}

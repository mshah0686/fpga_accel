#include <memory>
#include "Vtb_spi_handshake.h"
#include "verilated.h"

int main(int argc, char** argv) {
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true); 

    auto dut = std::make_unique<Vtb_spi_handshake>(contextp.get());

    while (!contextp->gotFinish()) {
        dut->eval();
        if (contextp->gotFinish()) break; // 👈 The absolute necessary safety brake
        contextp->time(dut->nextTimeSlot());
    }

    dut->final(); // Automatically flushes and writes the wave file
    return 0;
}

#include "Vtb_spi_handshake_top.h"
#include "verilated.h"

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);

    Vtb_spi_handshake_top dut;

    while (!Verilated::gotFinish()) {
        dut.eval();
    }

    return 0;
}
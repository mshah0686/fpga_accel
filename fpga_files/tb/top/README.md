This test bench instantiates the full chip `top` (SPI front-end + register model + 2x2 matrix multiplier + timer/display).
- TB drives the SPI signals (via `send_spi_word`) and generates the fast base clock + derived system clock
- No stimulus or checking yet - setup + SPI helper only, for waveform review
- Build target: `top_tb`, VCD written to `waves/tb_top.vcd` (run from the `fpga_files/` root)

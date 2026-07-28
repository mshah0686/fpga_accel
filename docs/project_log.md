# Intro
This project is to learn Embedded + FPGA + RTL Design. This markdown is a log of the project status as I develop the project serving as an engineering journal to log the hiccups and solutions I face.


# July 1st, 2026
## Status
- The ESP32 SPI code was finish and FPGA code was finished. FPGA design is simple - take SPI data in a shift register, send to async fifo, and then read from async fifo.
- The write to async fifo and SPI transactions are done on the ESP32 output SPI_CLK. The read side and display to seven segment and UART are done on the internal 25Mhz Clock.

## Cool Issues:
- On first attempt, SPI clock was at 10 MHZ. This led to garbage data being read. Slowed this down to 1Mhz for debug and looks to be stable. Will debug from here to proceed to 10Mhz
- At the 10Hmz frequency, I notice that only when the second transaction from ESP32 is sent, do I see data appear from the previous UART transaction. I'm unsure why and don't have FPGA debug tools like JTAG. Here is what I did:
    - Attached LED output to data on the read side to validate shift register. Then tied them to the read data from the fifo. This showed me that read was not happening in the fifo
    - Attached LED output then to the write data counter to see when it incremented. THis showed me that it only incremened on the second packet onward (never the first packet out of reset).
    - I only have a 24Mhz scope so it is really only feasible to debug SPI txn at 12.5Mhz or less. Or I can sample the 
From above, I concluded that the read is probably fine and the SPI data transmit is probably fine. 
Then I read about ESP 32 SPI code. It said the clock is only active when the chip select is low! This meant, when the SPI module asserted valid out, there was no clock edge ont the SPI_CLK for the async_fifo to latch the valid and actually process it until the next UART txn. 

## Next Steps
To confirm this - I will attach an LED to the valid signal from SPI to see it hold high between transactions. I have couple ideas for solutions:
1. Send dummy bits at the end of ESP32 for 2 cycles to allow the fifo to flush. SPI module drop these 2 dummy cycles
2. Have a RX data MISO connection that SPI module sends back to ESP32 as a confirmation. Either tie this to the fifo write actually happening or a floating delay to force the latch.
I think 2 is a good approach since I will likely need a data read back path. Will work on implementing this on FPGA SPI module next.

# July 10th, 2026
# Status
- Updated code to have handshake output from SPI for CDC instead of async fifo that relies on spi clk (spi_clk is not constant on)
- Set up verilator + waves on Mac with Cmake files. Simulated new code on spi_handshake_tb on branch. This was a huge plus to be able to work on simulation outside of ModelSim.
- Flashed and test both sides - able to send data from ESP32 and display on FPGA at 10Mhz. Faster clock rates cannot be handled by FPGA that is 25Mhz. 
# Cool Issues:
- Debugging is still a pain since I don't have visibility into the FPGA. Have to use LEDs and PWM signals on logic analyzer. Logic analyzer cannot capture all FPGA signals since they are both 25Mhz and break Nyquist sampling
# Next Steps
- Implement FPGA -> ESP 32 write. Need to architect what the system looks like
- Calculate SPI data transmit timing as FPGA needs to do downstream processing. 
- Architect what I am going to send and in what bursts.

# July 13, 2026
## Expanding SPI
Need to expand SPI to send commands, address to registers, and then have the FPGA respond with data. I'm going to start with something simple. This will be the approach. I will experiment with optimization later.
1. Each transaction will be 4 bytes
2. First byte will be comamnd - read = 0x2, write = 0x1, and NOP = 0x0.
3. Next byte will be address (8 bits)
4. Next 2 bytes will be data (2 byte data)
5. For a write transaction, you only need one transaction. For read, the microcontroller must send dummy transaction following a read with "NOP" and FPGA will respond with data. This has to be done because there is CDC between SPI module and FPGA. This causes 2 cycle sync between data from uController -> FPGA and data from FPGA -> SPI module. This 8 cycle total prevents data from being latched and responded to. We can either add dummy cycles in the transaction or do a new transaction. For now, it's easier to just send a new transaction. I will go with that.

Just for bringup testing and flow testing - I implemented a timer module with following SPI COMMAND structures. For now, I will tie the timer count to FPGA display. Later I will add read capability to read back to ESP32 from the FPGA.
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

# July 14th, 2026
Let's do some cycle calcuation for the SPI interface. First, assume SPI transmits at 10Mhz, FPGA operates at 25Mhz. To send SPI transaction of 32 bits, we need 32 cycles at 10Mhz which is 0.1 microseconds. It take 3.2 microseconds to send one packet. From there it takes about 3 cycles for the valid to assert on the sync. This is 0.04us * 3 = 0.12us. To send 32 bits, we take 3.2 + 0.12 = 3.32us which is about 9.66Mbs. 

Technically, the SPI could start sending the transaction for the next data by pipelining. It could start transmit for the next 32 bits while the rx sync is still processing. But since the FPGA clock speed is 2.5x the SPI clock speed, this is negligible. The bottleneck is SPI transmit speed at 10Mhz. Anything faster there we would see more speed up. The FPGA chip itself might not be able to handle a faster SPI routing. Will have to experiment with that packet loss.

In case of accelerator, we could double this speed at the cost of area. We could tie the another PWM port to the same CS and SCLK. If we needed to transfer large amounts of data, this is an architectural option. Instead of 1 bit per SCLK, we would transmit 2 bits. So the total would be 32 bits of data or 48 bits of data (depending if the second SPI is only data transmit). The cost is area in FPGA and complexity in merging packets downstream.


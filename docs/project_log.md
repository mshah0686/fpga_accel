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
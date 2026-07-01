/*
    Define all hardware connections
*/

// UART
#define HARDWARE_UART_TX_PIN 1
#define HARDWARE_UART_RX_PIN 3
#define HARDWARE_UART_PORT 0

// SPI
#define SPI_HOST    SPI2_HOST  // SPI2 is the standard user-facing SPI bus
#define SPI_MISO_PIN   12
#define SPI_MOSI_PIN   13
#define SPI_CLK_PIN    14
#define SPI_CS_PIN     15

#define SPI_FREQ 1 * 1000 * 1000 // 1Mhz

// LED
#define HARDWARE_ONBOARD_LED 2

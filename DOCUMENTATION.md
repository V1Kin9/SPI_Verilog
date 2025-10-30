# SPI Verilog Implementation

A comprehensive SPI (Serial Peripheral Interface) implementation in Verilog, designed to be compatible with STM32F4XXX SPI interfaces.

## Overview

This project provides both SPI Master and SPI Slave modules with configurable parameters to support various SPI modes and configurations commonly used in STM32F4XXX microcontrollers.

## Features

### SPI Master Module (`spi_master.v`)
- **Configurable Parameters:**
  - Data width: 8, 16, or 32 bits
  - Clock polarity (CPOL): 0 or 1
  - Clock phase (CPHA): 0 or 1
  - Bit order: MSB first or LSB first
  - Clock divider for adjustable SPI clock speed

- **Functionality:**
  - Full-duplex communication
  - Automatic chip select (CS) control
  - Busy flag indication
  - Done pulse on transfer completion
  - Compatible with all 4 SPI modes

### SPI Slave Module (`spi_slave.v`)
- **Configurable Parameters:**
  - Data width: 8, 16, or 32 bits
  - Clock polarity (CPOL): 0 or 1
  - Clock phase (CPHA): 0 or 1
  - Bit order: MSB first or LSB first

- **Functionality:**
  - Full-duplex communication
  - Clock domain crossing synchronization
  - RX data valid indication
  - Busy flag indication
  - Compatible with all 4 SPI modes

## SPI Modes

The modules support all 4 standard SPI modes through CPOL and CPHA configuration:

| Mode | CPOL | CPHA | Clock Polarity | Clock Phase |
|------|------|------|----------------|-------------|
| 0    | 0    | 0    | Low when idle  | Sample on leading edge |
| 1    | 0    | 1    | Low when idle  | Sample on trailing edge |
| 2    | 1    | 0    | High when idle | Sample on leading edge |
| 3    | 1    | 1    | High when idle | Sample on trailing edge |

## STM32F4XXX Compatibility

The SPI modules are designed to interface with STM32F4XXX microcontroller SPI peripherals. Key compatibility features:

### Signal Mapping
- `spi_sck` ↔ STM32 SCK (Serial Clock)
- `spi_mosi` ↔ STM32 MOSI (Master Out Slave In)
- `spi_miso` ↔ STM32 MISO (Master In Slave Out)
- `spi_cs_n` ↔ STM32 NSS (Chip Select, active low)

### Configuration Alignment
The STM32F4XXX SPI control registers (SPI_CR1, SPI_CR2) allow configuration of:
- **CPOL (Clock Polarity):** Maps directly to CPOL parameter
- **CPHA (Clock Phase):** Maps directly to CPHA parameter
- **LSBFIRST:** Maps to MSB_FIRST parameter (inverted logic)
- **BR[2:0] (Baud Rate Control):** Equivalent to CLK_DIV parameter in master

### Typical STM32 SPI Configuration Example
```c
// STM32 SPI configuration for Mode 0, 8-bit, MSB first
SPI_InitStructure.SPI_Direction = SPI_Direction_2Lines_FullDuplex;
SPI_InitStructure.SPI_Mode = SPI_Mode_Master;
SPI_InitStructure.SPI_DataSize = SPI_DataSize_8b;        // 8-bit data
SPI_InitStructure.SPI_CPOL = SPI_CPOL_Low;               // CPOL = 0
SPI_InitStructure.SPI_CPHA = SPI_CPHA_1Edge;             // CPHA = 0
SPI_InitStructure.SPI_NSS = SPI_NSS_Soft;
SPI_InitStructure.SPI_BaudRatePrescaler = SPI_BaudRatePrescaler_4;
SPI_InitStructure.SPI_FirstBit = SPI_FirstBit_MSB;       // MSB first
```

Corresponding Verilog module instantiation:
```verilog
spi_master #(
    .DATA_WIDTH(8),      // 8-bit data
    .CPOL(0),            // Clock polarity low
    .CPHA(0),            // Clock phase first edge
    .MSB_FIRST(1),       // MSB first
    .CLK_DIV(4)          // Clock divider (prescaler)
) spi_master_inst (
    // connections...
);
```

## Module Interfaces

### SPI Master Interface
```verilog
module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CPOL = 0,
    parameter CPHA = 0,
    parameter MSB_FIRST = 1,
    parameter CLK_DIV = 2
)(
    // System signals
    input  wire                     clk,        // System clock
    input  wire                     rst_n,      // Active low reset
    
    // Control signals
    input  wire                     start,      // Start transmission
    input  wire [DATA_WIDTH-1:0]    tx_data,    // Data to transmit
    output reg  [DATA_WIDTH-1:0]    rx_data,    // Received data
    output reg                      busy,       // Transfer in progress
    output reg                      done,       // Transfer complete
    
    // SPI interface
    output reg                      spi_sck,    // SPI clock
    output reg                      spi_mosi,   // Master Out Slave In
    input  wire                     spi_miso,   // Master In Slave Out
    output reg                      spi_cs_n    // Chip select (active low)
);
```

### SPI Slave Interface
```verilog
module spi_slave #(
    parameter DATA_WIDTH = 8,
    parameter CPOL = 0,
    parameter CPHA = 0,
    parameter MSB_FIRST = 1
)(
    // System signals
    input  wire                     clk,        // System clock
    input  wire                     rst_n,      // Active low reset
    
    // Control signals
    input  wire [DATA_WIDTH-1:0]    tx_data,    // Data to transmit
    output reg  [DATA_WIDTH-1:0]    rx_data,    // Received data
    input  wire                     tx_valid,   // TX data valid
    output reg                      rx_valid,   // RX data valid
    output reg                      busy,       // Transfer in progress
    
    // SPI interface
    input  wire                     spi_sck,    // SPI clock
    input  wire                     spi_mosi,   // Master Out Slave In
    output reg                      spi_miso,   // Master In Slave Out
    input  wire                     spi_cs_n    // Chip select (active low)
);
```

## Usage Examples

### SPI Master Usage
```verilog
// Instantiate SPI master
spi_master #(
    .DATA_WIDTH(8),
    .CPOL(0),
    .CPHA(0),
    .MSB_FIRST(1),
    .CLK_DIV(4)
) spi_master_inst (
    .clk(sys_clk),
    .rst_n(reset_n),
    .start(spi_start),
    .tx_data(data_to_send),
    .rx_data(data_received),
    .busy(spi_busy),
    .done(spi_done),
    .spi_sck(spi_clk),
    .spi_mosi(spi_mosi_signal),
    .spi_miso(spi_miso_signal),
    .spi_cs_n(spi_cs_signal)
);

// To send data:
// 1. Wait for busy = 0
// 2. Set tx_data to desired value
// 3. Pulse start high for one clock cycle
// 4. Wait for done pulse
// 5. Read rx_data
```

### SPI Slave Usage
```verilog
// Instantiate SPI slave
spi_slave #(
    .DATA_WIDTH(8),
    .CPOL(0),
    .CPHA(0),
    .MSB_FIRST(1)
) spi_slave_inst (
    .clk(sys_clk),
    .rst_n(reset_n),
    .tx_data(data_to_send),
    .rx_data(data_received),
    .tx_valid(tx_data_ready),
    .rx_valid(rx_data_ready),
    .busy(spi_busy),
    .spi_sck(spi_clk_from_master),
    .spi_mosi(spi_mosi_from_master),
    .spi_miso(spi_miso_to_master),
    .spi_cs_n(spi_cs_from_master)
);

// To prepare data for transmission:
// 1. Set tx_data to desired value
// 2. Pulse tx_valid high for one clock cycle
// 3. When master initiates transfer, data will be sent
// 4. Wait for rx_valid pulse to read received data
```

## Testing

Testbenches are provided for both modules:
- `tb_spi_master.v` - Comprehensive testbench for SPI master
- `tb_spi_slave.v` - Testbench for SPI slave

### Running Tests with Icarus Verilog

```bash
# Test SPI Master
iverilog -o spi_master_sim spi_master.v tb_spi_master.v
vvp spi_master_sim

# Test SPI Slave
iverilog -o spi_slave_sim spi_slave.v tb_spi_slave.v
vvp spi_slave_sim
```

### Viewing Waveforms
The testbenches generate VCD files for waveform viewing:

```bash
# Install GTKWave if not already installed
# Ubuntu/Debian: sudo apt-get install gtkwave

# View waveforms
gtkwave spi_master_tb.vcd
gtkwave spi_slave_tb.vcd
```

## Timing Diagrams

### SPI Mode 0 (CPOL=0, CPHA=0)
```
CS_N   ‾‾‾‾‾\_____________________/‾‾‾‾‾
SCK    ______/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_____
MOSI   ------< B7 X B6 X B5 X ... X B0 >-
MISO   ------< B7 X B6 X B5 X ... X B0 >-
       Sample ^   ^   ^         ^
       Shift      ^   ^   ^         ^
```

### SPI Mode 1 (CPOL=0, CPHA=1)
```
CS_N   ‾‾‾‾‾\_____________________/‾‾‾‾‾
SCK    ______/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_____
MOSI   ------< B7 X B6 X B5 X ... X B0 >-
MISO   ------< B7 X B6 X B5 X ... X B0 >-
       Shift  ^   ^   ^         ^
       Sample     ^   ^   ^         ^
```

## Performance

### Clock Frequency
- System clock: Configurable (e.g., 100 MHz)
- SPI clock: System clock / CLK_DIV
- Example: With 100 MHz system clock and CLK_DIV=4, SPI clock = 25 MHz

### Throughput
- Data rate = SPI clock frequency × bits per transfer
- Example: 25 MHz SPI clock × 8 bits = 200 Mbps

## Implementation Notes

### FPGA Resource Usage
- Minimal logic resources required
- No DSP blocks needed
- Small number of flip-flops and LUTs
- Suitable for small to large FPGAs

### Clock Domain Considerations
- **Master Module:** Operates entirely in system clock domain
- **Slave Module:** Includes synchronizers for SPI clock domain crossing
- Slave module adds 2-3 clock cycle latency for synchronization

### Reset Behavior
- Active-low asynchronous reset
- All outputs driven to safe defaults on reset
- State machines return to IDLE state

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## References

- [STM32F4xx Reference Manual](https://www.st.com/resource/en/reference_manual/dm00031020.pdf)
- [SPI Protocol Specification](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface)
- STM32F4 SPI peripheral documentation (RM0090)

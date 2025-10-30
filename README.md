# SPI_Verilog
Implement the SPI module using Verilog, referring to the STM32 peripheral documentation.

## Overview
This project provides a complete SPI (Serial Peripheral Interface) implementation in Verilog, designed to be compatible with STM32F4XXX microcontroller SPI interfaces.

## Features
- **SPI Master Module** (`spi_master.v`) - Full-featured SPI master controller
- **SPI Slave Module** (`spi_slave.v`) - SPI slave with clock domain crossing synchronization
- Configurable CPOL, CPHA, data width (8/16/32 bits), and bit order
- Full-duplex communication
- Compatible with all 4 SPI modes
- STM32F4XXX peripheral compatibility

## Quick Start

### Build and Test
```bash
make test          # Run all tests
make test-master   # Test SPI master only
make test-slave    # Test SPI slave only
make clean         # Clean generated files
```

### Files
- `spi_master.v` - SPI master module
- `spi_slave.v` - SPI slave module
- `tb_spi_master.v` - Master testbench
- `tb_spi_slave.v` - Slave testbench
- `spi_example.v` - Usage example
- `DOCUMENTATION.md` - Comprehensive documentation
- `Makefile` - Build automation

## Documentation
See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed information on:
- Module interfaces and parameters
- STM32F4XXX compatibility
- Usage examples
- Timing diagrams
- Implementation notes

## Requirements
- Icarus Verilog (for simulation)
- GTKWave (optional, for waveform viewing)

## License
MIT License


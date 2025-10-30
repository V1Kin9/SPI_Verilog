# Makefile for SPI Verilog Project
# Supports Icarus Verilog simulation

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Source files
SRC_MASTER = spi_master.v
SRC_SLAVE = spi_slave.v
TB_MASTER = tb_spi_master.v
TB_SLAVE = tb_spi_slave.v

# Output files
SIM_MASTER = spi_master_sim
SIM_SLAVE = spi_slave_sim
VCD_MASTER = spi_master_tb.vcd
VCD_SLAVE = spi_slave_tb.vcd

# Default target
.PHONY: all
all: test

# Build master simulation
$(SIM_MASTER): $(SRC_MASTER) $(TB_MASTER)
	@echo "Building SPI Master simulation..."
	$(IVERILOG) -o $(SIM_MASTER) $(SRC_MASTER) $(TB_MASTER)

# Build slave simulation
$(SIM_SLAVE): $(SRC_SLAVE) $(TB_SLAVE)
	@echo "Building SPI Slave simulation..."
	$(IVERILOG) -o $(SIM_SLAVE) $(SRC_SLAVE) $(TB_SLAVE)

# Run master test
.PHONY: test-master
test-master: $(SIM_MASTER)
	@echo "Running SPI Master tests..."
	$(VVP) $(SIM_MASTER)

# Run slave test
.PHONY: test-slave
test-slave: $(SIM_SLAVE)
	@echo "Running SPI Slave tests..."
	$(VVP) $(SIM_SLAVE)

# Run all tests
.PHONY: test
test: test-master test-slave
	@echo ""
	@echo "All tests completed!"

# View master waveform
.PHONY: wave-master
wave-master: $(VCD_MASTER)
	@echo "Opening SPI Master waveform..."
	$(GTKWAVE) $(VCD_MASTER) &

# View slave waveform
.PHONY: wave-slave
wave-slave: $(VCD_SLAVE)
	@echo "Opening SPI Slave waveform..."
	$(GTKWAVE) $(VCD_SLAVE) &

# Clean generated files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -f $(SIM_MASTER) $(SIM_SLAVE)
	rm -f $(VCD_MASTER) $(VCD_SLAVE)
	rm -f *.vcd *.out

# Help
.PHONY: help
help:
	@echo "SPI Verilog Project Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Run all tests (default)"
	@echo "  test         - Run all tests"
	@echo "  test-master  - Run SPI master tests"
	@echo "  test-slave   - Run SPI slave tests"
	@echo "  wave-master  - View SPI master waveform (requires GTKWave)"
	@echo "  wave-slave   - View SPI slave waveform (requires GTKWave)"
	@echo "  clean        - Remove generated files"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - Icarus Verilog (iverilog, vvp)"
	@echo "  - GTKWave (optional, for waveform viewing)"

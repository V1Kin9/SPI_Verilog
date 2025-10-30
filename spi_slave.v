//******************************************************************************
// SPI Slave Module
// Compatible with STM32F4XXX SPI Interface
//
// Features:
// - Configurable clock polarity (CPOL) and phase (CPHA)
// - Configurable data width (8/16/32 bits)
// - MSB or LSB first transmission
// - Full-duplex communication
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

module spi_slave #(
    parameter DATA_WIDTH = 8,        // Data width: 8, 16, or 32 bits
    parameter CPOL = 0,              // Clock polarity: 0 or 1
    parameter CPHA = 0,              // Clock phase: 0 or 1
    parameter MSB_FIRST = 1          // 1: MSB first, 0: LSB first
)(
    // System signals
    input  wire                     clk,        // System clock (for synchronization)
    input  wire                     rst_n,      // Active low reset
    
    // Control signals
    input  wire [DATA_WIDTH-1:0]    tx_data,    // Data to transmit
    output reg  [DATA_WIDTH-1:0]    rx_data,    // Received data
    input  wire                     tx_valid,   // TX data valid
    output reg                      rx_valid,   // RX data valid (1 clock pulse)
    output reg                      busy,       // Transfer in progress
    
    // SPI interface
    input  wire                     spi_sck,    // SPI clock from master
    input  wire                     spi_mosi,   // Master Out Slave In
    output reg                      spi_miso,   // Master In Slave Out
    input  wire                     spi_cs_n    // Chip select (active low)
);

    // Internal registers
    reg [DATA_WIDTH-1:0]    tx_shift_reg;
    reg [DATA_WIDTH-1:0]    rx_shift_reg;
    reg [DATA_WIDTH-1:0]    tx_buffer;  // Buffer for tx_data
    reg                     tx_buffer_valid;
    reg [$clog2(DATA_WIDTH):0] bit_cnt;
    
    // Synchronize SPI signals to system clock
    reg [2:0] sck_sync;
    reg [2:0] cs_sync;
    reg [2:0] mosi_sync;
    
    wire sck_rising_edge;
    wire sck_falling_edge;
    wire cs_active;
    wire cs_falling_edge;
    
    // Clock domain crossing synchronizers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_sync <= 3'b000;
            cs_sync <= 3'b111;
            mosi_sync <= 3'b000;
        end else begin
            sck_sync <= {sck_sync[1:0], spi_sck};
            cs_sync <= {cs_sync[1:0], spi_cs_n};
            mosi_sync <= {mosi_sync[1:0], spi_mosi};
        end
    end
    
    // Edge detection
    assign sck_rising_edge = (sck_sync[2:1] == 2'b01);
    assign sck_falling_edge = (sck_sync[2:1] == 2'b10);
    assign cs_active = ~cs_sync[1];  // Use bit [1] for better timing
    assign cs_falling_edge = (cs_sync[2:1] == 2'b10);
    
    // Determine sample and shift edges based on CPOL and CPHA
    wire sample_edge = (CPOL == 0) ? 
                       ((CPHA == 0) ? sck_rising_edge : sck_falling_edge) :
                       ((CPHA == 0) ? sck_falling_edge : sck_rising_edge);
                       
    wire shift_edge = (CPOL == 0) ?
                      ((CPHA == 0) ? sck_falling_edge : sck_rising_edge) :
                      ((CPHA == 0) ? sck_rising_edge : sck_falling_edge);
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 0;
            rx_valid <= 1'b0;
            busy <= 1'b0;
            spi_miso <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt <= 0;
            tx_buffer <= 0;
            tx_buffer_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;  // Default: pulse for one cycle
            
            // Buffer tx_data when tx_valid is asserted
            if (tx_valid) begin
                tx_buffer <= tx_data;
                tx_buffer_valid <= 1'b1;
            end
            
            if (cs_falling_edge) begin
                // CS activated - start new transfer
                busy <= 1'b1;
                bit_cnt <= 0;
                
                if (tx_buffer_valid) begin
                    tx_shift_reg <= tx_buffer;
                    
                    // For CPHA=0, output first bit immediately
                    if (CPHA == 0) begin
                        if (MSB_FIRST) begin
                            spi_miso <= tx_buffer[DATA_WIDTH-1];
                        end else begin
                            spi_miso <= tx_buffer[0];
                        end
                    end
                end else begin
                    tx_shift_reg <= 0;  // Send zeros if no valid data
                    spi_miso <= 1'b0;
                end
                
                // Clear buffer valid flag after use
                tx_buffer_valid <= 1'b0;
            end
            
            if (cs_active) begin
                // Handle data transfer on clock edges
                if (sample_edge) begin
                    // Sample MOSI data
                    if (MSB_FIRST) begin
                        rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], mosi_sync[2]};
                    end else begin
                        rx_shift_reg <= {mosi_sync[2], rx_shift_reg[DATA_WIDTH-1:1]};
                    end
                    
                    bit_cnt <= bit_cnt + 1;
                    
                    // Check if transfer is complete
                    if (bit_cnt == DATA_WIDTH - 1) begin
                        rx_data <= MSB_FIRST ? 
                                   {rx_shift_reg[DATA_WIDTH-2:0], mosi_sync[2]} :
                                   {mosi_sync[2], rx_shift_reg[DATA_WIDTH-1:1]};
                        rx_valid <= 1'b1;
                        busy <= 1'b0;
                    end
                end
                
                if (shift_edge) begin
                    // Shift out MISO data
                    if (MSB_FIRST) begin
                        tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                        spi_miso <= tx_shift_reg[DATA_WIDTH-1];
                    end else begin
                        tx_shift_reg <= {1'b0, tx_shift_reg[DATA_WIDTH-1:1]};
                        spi_miso <= tx_shift_reg[0];
                    end
                end
            end else begin
                // CS inactive - idle state
                busy <= 1'b0;
                spi_miso <= 1'b0;
            end
        end
    end

endmodule

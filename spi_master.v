//******************************************************************************
// SPI Master Module
// Compatible with STM32F4XXX SPI Interface
//
// Features:
// - Configurable clock polarity (CPOL) and phase (CPHA)
// - Configurable data width (8/16/32 bits)
// - MSB or LSB first transmission
// - Full-duplex communication
// - Automatic chip select control
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

module spi_master #(
    parameter DATA_WIDTH = 8,        // Data width: 8, 16, or 32 bits
    parameter CPOL = 0,              // Clock polarity: 0 or 1
    parameter CPHA = 0,              // Clock phase: 0 or 1
    parameter MSB_FIRST = 1,         // 1: MSB first, 0: LSB first
    parameter CLK_DIV = 2            // Clock divider (must be even, >= 2)
)(
    // System signals
    input  wire                     clk,        // System clock
    input  wire                     rst_n,      // Active low reset
    
    // Control signals
    input  wire                     start,      // Start transmission
    input  wire [DATA_WIDTH-1:0]    tx_data,    // Data to transmit
    output reg  [DATA_WIDTH-1:0]    rx_data,    // Received data
    output reg                      busy,       // Transfer in progress
    output reg                      done,       // Transfer complete (1 clock pulse)
    
    // SPI interface
    output reg                      spi_sck,    // SPI clock
    output reg                      spi_mosi,   // Master Out Slave In
    input  wire                     spi_miso,   // Master In Slave Out
    output reg                      spi_cs_n    // Chip select (active low)
);

    // State machine states
    localparam IDLE     = 2'b00;
    localparam SETUP    = 2'b01;
    localparam TRANSFER = 2'b10;
    localparam FINISH   = 2'b11;
    
    // Internal registers
    reg [1:0]               state;
    reg [DATA_WIDTH-1:0]    tx_shift_reg;
    reg [DATA_WIDTH-1:0]    rx_shift_reg;
    reg [$clog2(DATA_WIDTH):0] bit_cnt;
    reg [$clog2(CLK_DIV)-1:0]  clk_cnt;
    reg                     sck_enable;
    reg                     sck_toggle;
    
    // Generate SPI clock
    wire spi_clk_idle = CPOL ? 1'b1 : 1'b0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            sck_toggle <= 1'b0;
        end else begin
            if (sck_enable) begin
                if (clk_cnt == (CLK_DIV/2 - 1)) begin
                    clk_cnt <= 0;
                    sck_toggle <= ~sck_toggle;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end else begin
                clk_cnt <= 0;
                sck_toggle <= 1'b0;
            end
        end
    end
    
    // Generate SPI SCK based on CPOL
    always @(*) begin
        if (sck_enable) begin
            if (CPOL == 0)
                spi_sck = sck_toggle;
            else
                spi_sck = ~sck_toggle;
        end else begin
            spi_sck = spi_clk_idle;
        end
    end
    
    // Determine when to sample and shift based on CPHA
    wire sample_edge = (CPHA == 0) ? sck_toggle : ~sck_toggle;
    wire shift_edge  = (CPHA == 0) ? ~sck_toggle : sck_toggle;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            spi_cs_n <= 1'b1;
            spi_mosi <= 1'b0;
            rx_data <= 0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt <= 0;
            sck_enable <= 1'b0;
        end else begin
            done <= 1'b0;  // Default: done is only high for one cycle
            
            case (state)
                IDLE: begin
                    spi_cs_n <= 1'b1;
                    sck_enable <= 1'b0;
                    busy <= 1'b0;
                    
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= DATA_WIDTH;
                        state <= SETUP;
                        busy <= 1'b1;
                    end
                end
                
                SETUP: begin
                    spi_cs_n <= 1'b0;  // Assert chip select
                    
                    // Wait one clock cycle before starting transfer
                    state <= TRANSFER;
                    sck_enable <= 1'b1;
                    
                    // For CPHA=0, set first bit before first clock edge
                    if (CPHA == 0) begin
                        if (MSB_FIRST)
                            spi_mosi <= tx_shift_reg[DATA_WIDTH-1];
                        else
                            spi_mosi <= tx_shift_reg[0];
                    end
                end
                
                TRANSFER: begin
                    // Handle data transfer on clock edges
                    if (clk_cnt == (CLK_DIV/2 - 1)) begin
                        if (shift_edge) begin
                            // Shift data out (on shift edge)
                            if (MSB_FIRST) begin
                                tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                                spi_mosi <= tx_shift_reg[DATA_WIDTH-1];
                            end else begin
                                tx_shift_reg <= {1'b0, tx_shift_reg[DATA_WIDTH-1:1]};
                                spi_mosi <= tx_shift_reg[0];
                            end
                        end else if (sample_edge) begin
                            // Sample data in (on sample edge)
                            if (MSB_FIRST) begin
                                rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], spi_miso};
                            end else begin
                                rx_shift_reg <= {spi_miso, rx_shift_reg[DATA_WIDTH-1:1]};
                            end
                            
                            bit_cnt <= bit_cnt - 1;
                            
                            if (bit_cnt == 1) begin
                                state <= FINISH;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    sck_enable <= 1'b0;
                    spi_cs_n <= 1'b1;  // Deassert chip select
                    rx_data <= rx_shift_reg;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

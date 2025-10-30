//******************************************************************************
// STM32 Integration Example
// Shows how to interface the SPI Verilog modules with STM32F4XXX
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

/*
 * STM32 Configuration Example (C code for STM32F4):
 * 
 * // Enable SPI1 clock
 * RCC_APB2PeriphClockCmd(RCC_APB2Periph_SPI1, ENABLE);
 * 
 * // Configure GPIO pins for SPI1
 * // PA5 -> SCK, PA6 -> MISO, PA7 -> MOSI, PA4 -> NSS
 * GPIO_InitTypeDef GPIO_InitStructure;
 * GPIO_InitStructure.GPIO_Pin = GPIO_Pin_5 | GPIO_Pin_6 | GPIO_Pin_7;
 * GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF;
 * GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
 * GPIO_InitStructure.GPIO_OType = GPIO_OType_PP;
 * GPIO_InitStructure.GPIO_PuPd = GPIO_PuPd_DOWN;
 * GPIO_Init(GPIOA, &GPIO_InitStructure);
 * 
 * // Connect pins to SPI1 alternate function
 * GPIO_PinAFConfig(GPIOA, GPIO_PinSource5, GPIO_AF_SPI1);  // SCK
 * GPIO_PinAFConfig(GPIOA, GPIO_PinSource6, GPIO_AF_SPI1);  // MISO
 * GPIO_PinAFConfig(GPIOA, GPIO_PinSource7, GPIO_AF_SPI1);  // MOSI
 * 
 * // Configure SPI1
 * SPI_InitTypeDef SPI_InitStructure;
 * SPI_InitStructure.SPI_Direction = SPI_Direction_2Lines_FullDuplex;
 * SPI_InitStructure.SPI_Mode = SPI_Mode_Master;
 * SPI_InitStructure.SPI_DataSize = SPI_DataSize_8b;
 * SPI_InitStructure.SPI_CPOL = SPI_CPOL_Low;               // CPOL = 0
 * SPI_InitStructure.SPI_CPHA = SPI_CPHA_1Edge;             // CPHA = 0
 * SPI_InitStructure.SPI_NSS = SPI_NSS_Soft;
 * SPI_InitStructure.SPI_BaudRatePrescaler = SPI_BaudRatePrescaler_4;
 * SPI_InitStructure.SPI_FirstBit = SPI_FirstBit_MSB;
 * SPI_InitStructure.SPI_CRCPolynomial = 7;
 * SPI_Init(SPI1, &SPI_InitStructure);
 * 
 * // Enable SPI1
 * SPI_Cmd(SPI1, ENABLE);
 * 
 * // Send/Receive data
 * uint8_t data_to_send = 0xA5;
 * uint8_t received_data;
 * 
 * // Wait until transmit buffer is empty
 * while (SPI_I2S_GetFlagStatus(SPI1, SPI_I2S_FLAG_TXE) == RESET);
 * 
 * // Send data
 * SPI_I2S_SendData(SPI1, data_to_send);
 * 
 * // Wait until receive buffer is not empty
 * while (SPI_I2S_GetFlagStatus(SPI1, SPI_I2S_FLAG_RXNE) == RESET);
 * 
 * // Read received data
 * received_data = SPI_I2S_ReceiveData(SPI1);
 */

// Corresponding Verilog module (FPGA side as slave)
module stm32_fpga_interface (
    input  wire       fpga_clk,       // FPGA system clock (e.g., 50MHz or 100MHz)
    input  wire       fpga_rst_n,     // FPGA reset
    
    // SPI interface to STM32
    input  wire       stm32_sck,      // From STM32 SCK (PA5)
    input  wire       stm32_mosi,     // From STM32 MOSI (PA7)
    output wire       stm32_miso,     // To STM32 MISO (PA6)
    input  wire       stm32_cs_n,     // From STM32 NSS (PA4)
    
    // Internal FPGA logic interface
    output reg  [7:0] received_data,  // Data received from STM32
    output reg        data_valid,     // Pulse when new data received
    input  wire [7:0] send_data,      // Data to send to STM32
    input  wire       send_valid      // Assert to load new send data
);

    // SPI Slave instance matching STM32 configuration
    wire [7:0] spi_rx_data;
    wire       spi_rx_valid;
    wire       spi_busy;
    
    spi_slave #(
        .DATA_WIDTH(8),         // Match STM32 SPI_DataSize_8b
        .CPOL(0),               // Match STM32 SPI_CPOL_Low
        .CPHA(0),               // Match STM32 SPI_CPHA_1Edge
        .MSB_FIRST(1)           // Match STM32 SPI_FirstBit_MSB
    ) spi_slave_inst (
        .clk(fpga_clk),
        .rst_n(fpga_rst_n),
        .tx_data(send_data),
        .rx_data(spi_rx_data),
        .tx_valid(send_valid),
        .rx_valid(spi_rx_valid),
        .busy(spi_busy),
        .spi_sck(stm32_sck),
        .spi_mosi(stm32_mosi),
        .spi_miso(stm32_miso),
        .spi_cs_n(stm32_cs_n)
    );
    
    // Register received data
    always @(posedge fpga_clk or negedge fpga_rst_n) begin
        if (!fpga_rst_n) begin
            received_data <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            data_valid <= spi_rx_valid;
            if (spi_rx_valid) begin
                received_data <= spi_rx_data;
            end
        end
    end

endmodule

/*
 * Hardware Connections:
 * 
 * STM32F4 (Master)          FPGA (Slave)
 * ----------------          ------------
 * PA5 (SCK)      -------->  stm32_sck
 * PA7 (MOSI)     -------->  stm32_mosi
 * PA6 (MISO)     <--------  stm32_miso
 * PA4 (NSS/CS)   -------->  stm32_cs_n
 * GND            -------->  GND
 * 
 * Notes:
 * 1. Ensure proper voltage level translation if STM32 is 3.3V and FPGA is different
 * 2. Add pull-up/pull-down resistors as needed for CS line
 * 3. Keep trace lengths short for high-speed SPI communication
 * 4. Use ground plane for noise immunity
 * 5. Consider adding series resistors (22-33 ohms) on SPI lines for signal integrity
 * 
 * Timing Considerations:
 * - STM32F4 can run SPI up to 42 MHz (APB2 peripheral)
 * - Ensure FPGA system clock is fast enough (at least 4x SPI clock for synchronizers)
 * - Example: If SPI runs at 10 MHz, FPGA clock should be >=40 MHz
 * 
 * Configuration Guidelines:
 * - Always configure STM32 SPI before connecting to FPGA
 * - Match CPOL/CPHA settings on both sides
 * - Match data width (8/16 bit)
 * - Match bit order (MSB/LSB first)
 * - Test with slow SPI clock first, then increase speed
 */

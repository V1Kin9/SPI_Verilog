//******************************************************************************
// SPI Master-Slave Example
// Demonstrates how to connect and use SPI master and slave modules
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

module spi_example (
    input  wire clk,
    input  wire rst_n,
    input  wire start_transfer,
    input  wire [7:0] master_tx_data,
    output wire [7:0] master_rx_data,
    output wire transfer_done
);

    // SPI bus signals
    wire spi_sck;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs_n;
    
    // Master control signals
    wire master_busy;
    wire master_done;
    
    // Slave control signals
    reg  [7:0] slave_tx_data;
    wire [7:0] slave_rx_data;
    reg  slave_tx_valid;
    wire slave_rx_valid;
    wire slave_busy;
    
    // Instantiate SPI Master
    spi_master #(
        .DATA_WIDTH(8),
        .CPOL(0),
        .CPHA(0),
        .MSB_FIRST(1),
        .CLK_DIV(4)
    ) master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_transfer),
        .tx_data(master_tx_data),
        .rx_data(master_rx_data),
        .busy(master_busy),
        .done(master_done),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Instantiate SPI Slave
    spi_slave #(
        .DATA_WIDTH(8),
        .CPOL(0),
        .CPHA(0),
        .MSB_FIRST(1)
    ) slave_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .tx_valid(slave_tx_valid),
        .rx_valid(slave_rx_valid),
        .busy(slave_busy),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Slave logic: Echo received data back to master
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_tx_data <= 8'h00;
            slave_tx_valid <= 1'b0;
        end else begin
            slave_tx_valid <= 1'b0;  // Default
            
            if (slave_rx_valid) begin
                // Prepare to send back the received data
                slave_tx_data <= slave_rx_data;
                slave_tx_valid <= 1'b1;
            end
        end
    end
    
    assign transfer_done = master_done;

endmodule

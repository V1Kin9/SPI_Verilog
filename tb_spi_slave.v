//******************************************************************************
// SPI Slave Testbench
// Tests the SPI slave module with a simple master simulator
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

`timescale 1ns/1ps

module tb_spi_slave;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10;
    parameter SPI_CLK_PERIOD = 100;
    
    // System signals
    reg  clk;
    reg  rst_n;
    
    // Control signals
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    reg  tx_valid;
    wire rx_valid;
    wire busy;
    
    // SPI interface
    reg  spi_sck;
    reg  spi_mosi;
    wire spi_miso;
    reg  spi_cs_n;
    
    // Test variables
    integer test_count;
    integer pass_count;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(0),
        .CPHA(0),
        .MSB_FIRST(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .tx_valid(tx_valid),
        .rx_valid(rx_valid),
        .busy(busy),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Task: Reset system
    task reset_system;
        begin
            rst_n = 0;
            spi_sck = 0;
            spi_mosi = 0;
            spi_cs_n = 1;
            tx_data = 0;
            tx_valid = 0;
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(10) @(posedge clk);
        end
    endtask
    
    // Task: Send SPI data as master
    task master_send_byte;
        input [DATA_WIDTH-1:0] data_to_send;
        output [DATA_WIDTH-1:0] data_received;
        integer i;
        integer j;
        begin
            data_received = 0;
            
            // Assert CS
            @(posedge clk);
            spi_cs_n = 0;
            
            // Wait some clock cycles for synchronization
            repeat(5) @(posedge clk);
            
            // For CPHA=0, sample first bit before first clock edge
            data_received[DATA_WIDTH-1] = spi_miso;
            
            // Send 8 bits
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
                spi_mosi = data_to_send[i];
                
                // Wait half SPI clock period
                for (j = 0; j < (SPI_CLK_PERIOD/CLK_PERIOD/2); j = j + 1) begin
                    @(posedge clk);
                end
                
                spi_sck = 1;  // Rising edge
                
                // Wait a bit then sample MISO for next bit
                @(posedge clk);
                @(posedge clk);
                if (i > 0) begin
                    data_received[i-1] = spi_miso;
                end
                
                // Wait rest of half SPI clock period
                for (j = 0; j < (SPI_CLK_PERIOD/CLK_PERIOD/2) - 2; j = j + 1) begin
                    @(posedge clk);
                end
                
                spi_sck = 0;  // Falling edge
            end
            
            // Deassert CS
            repeat(5) @(posedge clk);
            spi_cs_n = 1;
            repeat(5) @(posedge clk);
        end
    endtask
    
    // Test variables for temporary storage
    reg [DATA_WIDTH-1:0] received;
    integer all_pass;
    integer i;
    reg rx_valid_captured;
    
    // Capture rx_valid pulse
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_valid_captured <= 0;
        end else if (rx_valid) begin
            rx_valid_captured <= 1;
        end
    end
    
    // Main test
    initial begin
        $display("====================================");
        $display("SPI Slave Testbench");
        $display("====================================");
        
        test_count = 0;
        pass_count = 0;
        
        reset_system();
        
        // Test 1: Basic receive
        $display("\n--- Test 1: Basic Receive ---");
        
        tx_data = 8'h42;
        tx_valid = 1;
        @(posedge clk);
        tx_valid = 0;
        rx_valid_captured = 0;
        
        master_send_byte(8'hA5, received);
        
        // Wait for rx_valid
        wait(rx_valid_captured);
        @(posedge clk);
        
        test_count = test_count + 1;
        if (rx_data == 8'hA5) begin
            pass_count = pass_count + 1;
            $display("[PASS] Received correct data: 0x%h", rx_data);
        end else begin
            $display("[FAIL] Expected 0xA5, got 0x%h", rx_data);
        end
        
        // Test 2: Check transmitted data
        $display("\n--- Test 2: Data Transmission ---");
        
        tx_data = 8'h5A;
        tx_valid = 1;
        @(posedge clk);
        tx_valid = 0;
        rx_valid_captured = 0;
        
        master_send_byte(8'h00, received);
        wait(rx_valid_captured);
        @(posedge clk);
        
        test_count = test_count + 1;
        if (received == 8'h5A) begin
            pass_count = pass_count + 1;
            $display("[PASS] Transmitted correct data: 0x%h", received);
        end else begin
            $display("[FAIL] Expected 0x5A, got 0x%h", received);
        end
        
        // Test 3: Multiple transfers
        $display("\n--- Test 3: Multiple Transfers ---");
        
        all_pass = 1;
        for (i = 0; i < 5; i = i + 1) begin
            tx_data = 8'h10 + i;
            tx_valid = 1;
            @(posedge clk);
            tx_valid = 0;
            rx_valid_captured = 0;
            
            master_send_byte(8'h20 + i, received);
            wait(rx_valid_captured);
            @(posedge clk);
            
            if (rx_data != (8'h20 + i)) begin
                all_pass = 0;
                $display("  [FAIL] Transfer %0d: Expected 0x%h, got 0x%h", 
                         i, 8'h20 + i, rx_data);
            end
        end
        
        test_count = test_count + 1;
        if (all_pass) begin
            pass_count = pass_count + 1;
            $display("[PASS] All transfers successful");
        end else begin
            $display("[FAIL] Some transfers failed");
        end
        
        // Display summary
        $display("\n====================================");
        $display("Test Summary");
        $display("====================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", test_count - pass_count);
        $display("====================================");
        
        if (pass_count == test_count) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $display("\nSimulation completed successfully");
        $finish;
    end
    
    // Timeout
    initial begin
        #500000;  // Increased timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end
    
    // Generate VCD
    initial begin
        $dumpfile("spi_slave_tb.vcd");
        $dumpvars(0, tb_spi_slave);
    end

endmodule

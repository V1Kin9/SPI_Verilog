//******************************************************************************
// SPI Master Testbench
// Tests various configurations and scenarios
//
// Author: SPI_Verilog Project
// License: MIT
//******************************************************************************

`timescale 1ns/1ps

module tb_spi_master;

    // Parameters for DUT
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10;  // 100MHz system clock
    parameter TEST_TIMEOUT = 100000;
    
    // System signals
    reg  clk;
    reg  rst_n;
    
    // Control signals
    reg  start;
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    wire busy;
    wire done;
    
    // SPI interface
    wire spi_sck;
    wire spi_mosi;
    reg  spi_miso;
    wire spi_cs_n;
    
    // Test variables
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation - CPOL=0, CPHA=0
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(0),
        .CPHA(0),
        .MSB_FIRST(1),
        .CLK_DIV(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Simple SPI slave simulator (loopback + increment)
    reg [DATA_WIDTH-1:0] slave_rx_data;
    reg [DATA_WIDTH-1:0] slave_tx_data;
    integer slave_bit_cnt;
    
    always @(posedge spi_sck or negedge spi_cs_n) begin
        if (!spi_cs_n) begin
            if (slave_bit_cnt == 0) begin
                // Prepare data to send back (echo + 1)
                slave_tx_data = slave_rx_data + 1;
            end
            
            // Shift in MOSI data
            slave_rx_data = {slave_rx_data[DATA_WIDTH-2:0], spi_mosi};
            
            // Shift out MISO data
            spi_miso = slave_tx_data[DATA_WIDTH-1];
            slave_tx_data = {slave_tx_data[DATA_WIDTH-2:0], 1'b0};
            
            slave_bit_cnt = slave_bit_cnt + 1;
            if (slave_bit_cnt >= DATA_WIDTH) begin
                slave_bit_cnt = 0;
            end
        end else begin
            slave_bit_cnt = 0;
            spi_miso = 1'b0;
        end
    end
    
    // Task: Reset the system
    task reset_system;
        begin
            rst_n = 0;
            start = 0;
            tx_data = 0;
            spi_miso = 0;
            slave_bit_cnt = 0;
            slave_rx_data = 0;
            slave_tx_data = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
        end
    endtask
    
    // Task: Send SPI transaction
    task send_spi_data;
        input [DATA_WIDTH-1:0] data;
        output [DATA_WIDTH-1:0] received;
        begin
            @(posedge clk);
            tx_data = data;
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait for transaction to complete
            wait(done);
            received = rx_data;
            @(posedge clk);
        end
    endtask
    
    // Task: Display test result
    task display_result;
        input integer test_num;
        input [255:0] test_name;
        input pass;
        begin
            test_count = test_count + 1;
            if (pass) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: %s", test_num, test_name);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: %s", test_num, test_name);
            end
        end
    endtask
    
    // Test variables for temporary storage
    reg [DATA_WIDTH-1:0] rx_temp;
    reg all_pass;
    integer i;
    integer done_count;
    
    // Main test sequence
    initial begin
        $display("====================================");
        $display("SPI Master Testbench");
        $display("====================================");
        
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Initialize signals
        reset_system();
        
        // Test 1: Basic transmission
        $display("\n--- Test 1: Basic Transmission ---");
        send_spi_data(8'hA5, rx_temp);
        display_result(1, "Basic transmission (0xA5)", slave_rx_data == 8'hA5);
        
        // Test 2: Multiple consecutive transfers
        $display("\n--- Test 2: Multiple Transfers ---");
        all_pass = 1;
        for (i = 0; i < 5; i = i + 1) begin
            send_spi_data(8'h10 + i, rx_temp);
            if (slave_rx_data != (8'h10 + i)) begin
                all_pass = 0;
                $display("  Transfer %0d failed: sent=0x%h, received=0x%h", 
                         i, 8'h10 + i, slave_rx_data);
            end
        end
        display_result(2, "Multiple consecutive transfers", all_pass);
        
        // Test 3: Check CS timing
        $display("\n--- Test 3: Chip Select Timing ---");
        @(posedge clk);
        tx_data = 8'h55;
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Check CS goes low
        #100;
        display_result(3, "CS asserted during transfer", spi_cs_n == 0);
        
        // Wait for completion
        wait(done);
        @(posedge clk);
        
        // Check CS goes high
        display_result(4, "CS deasserted after transfer", spi_cs_n == 1);
        
        // Test 4: Busy flag check
        $display("\n--- Test 4: Busy Flag ---");
        @(posedge clk);
        display_result(5, "Not busy in idle", busy == 0);
        
        tx_data = 8'h33;
        start = 1;
        @(posedge clk);
        start = 0;
        @(posedge clk);
        
        display_result(6, "Busy during transfer", busy == 1);
        
        wait(done);
        @(posedge clk);
        display_result(7, "Not busy after transfer", busy == 0);
        
        // Test 5: Different data patterns
        $display("\n--- Test 5: Data Patterns ---");
        all_pass = 1;
        
        // All zeros
        send_spi_data(8'h00, rx_temp);
        if (slave_rx_data != 8'h00) all_pass = 0;
        
        // All ones
        send_spi_data(8'hFF, rx_temp);
        if (slave_rx_data != 8'hFF) all_pass = 0;
        
        // Alternating pattern
        send_spi_data(8'hAA, rx_temp);
        if (slave_rx_data != 8'hAA) all_pass = 0;
        
        send_spi_data(8'h55, rx_temp);
        if (slave_rx_data != 8'h55) all_pass = 0;
        
        display_result(8, "Various data patterns", all_pass);
        
        // Test 6: Done pulse timing
        $display("\n--- Test 6: Done Pulse ---");
        @(posedge clk);
        tx_data = 8'h7E;
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for done and count cycles it's high
        done_count = 0;
        while (!done) @(posedge clk);
        
        // Now done is high, count how many cycles
        while (done) begin
            done_count = done_count + 1;
            @(posedge clk);
        end
        
        display_result(9, "Done pulse is one cycle", done_count == 1);
        
        // Display summary
        $display("\n====================================");
        $display("Test Summary");
        $display("====================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("====================================");
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $display("\nSimulation completed successfully");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #TEST_TIMEOUT;
        $display("\n[ERROR] Simulation timeout!");
        $display("Test may be stuck. Terminating...");
        $finish;
    end
    
    // Optional: Generate VCD for waveform viewing
    initial begin
        $dumpfile("spi_master_tb.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule

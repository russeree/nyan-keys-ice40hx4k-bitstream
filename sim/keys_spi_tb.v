`timescale 1ns/1ps

module tb_spi_keys;

    // Parameters
    parameter NUM_KEYS = 61;

    // Clock and reset signals
    reg clk_g_i;
    reg rstn_g_i;

    // SPI signals
    wire  spi_clk_g_o;
    wire  spi_mosi_g_o;

    // Key input signals
    reg [NUM_KEYS-1:0] keys_i_g;

    // Instantiate the spi_keys module
    spi_keys #(NUM_KEYS) uut (
        .clk_g_i(clk_g_i),
        .rstn_g_i(rstn_g_i),
        .spi_clk_g_o(spi_clk_g_o),
        .spi_mosi_g_o(spi_mosi_g_o),
        .keys_i_g(keys_i_g)
    );

    // Clock generation
    always begin
        #42 clk_g_i = ~clk_g_i;
    end

    // Test sequence
    initial begin
        // Initialization
        clk_g_i = 0;
        rstn_g_i = 1;
        keys_i_g = 0;

        // Start VCD Dump
        $dumpfile("spi_keys_tb.vcd");
        $dumpvars(0, tb_spi_keys);

        #10000;
        rstn_g_i = 0;
        #1000;
        rstn_g_i = 1;
        #10000;
        // Random key press
        keys_i_g = $random;
        #10000;
        keys_i_g = $random;
        #10000;
        keys_i_g = $random;
        #100000;

        // End simulation
        $finish;
    end

endmodule


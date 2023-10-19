`timescale 1ns/1ps

module tb_spi_keys;

    // Parameters
    parameter NUM_KEYS = 89;

    // Clock and reset signals
    reg clk_g_i;
    reg rstn_g_i;

    // SPI signals
    reg  spi_clk_g_i;
    reg  spi_mosi_g_i;
    wire spi_miso_g_o;
    reg  spi_cs_g_i;

    // Key input signals
    reg [NUM_KEYS-1:0] keys_i_g;

    // Instantiate the spi_keys module
    spi_keys #(NUM_KEYS) uut (
        .clk_g_i(clk_g_i),
        .rstn_g_i(rstn_g_i),
        .spi_clk_g_i(spi_clk_g_i),
        .spi_mosi_g_i(spi_mosi_g_i),
        .spi_miso_g_o(spi_miso_g_o),
        .spi_cs_g_i(spi_cs_g_i),
        .keys_i_g(keys_i_g)
    );

    // Clock generation
    always begin
        #8 clk_g_i = ~clk_g_i;
    end

    // Test sequence
    initial begin
        // Initialization
        clk_g_i = 0;
        spi_clk_g_i = 0;
        rstn_g_i = 1;
        spi_cs_g_i = 1;
        spi_mosi_g_i = 0;
        keys_i_g = 0;

        // Start VCD Dump
        $dumpfile("spi_keys_tb.vcd");
        $dumpvars(0, tb_spi_keys);

        #10;
        rstn_g_i = 0;
        #10;
        rstn_g_i = 1;
        #10;

        // Random key press
        keys_i_g = $random;
        #10;
        keys_i_g = $random;
        #10;
        // SPI read after key presses
        spi_cs_g_i = 0;
        for (integer i = 0; i < NUM_KEYS; i = i + 1) begin
            for (integer j = 7; j >= 0; j = j - 1) begin
                spi_mosi_g_i = i[j];
                #500;
                spi_clk_g_i = ~spi_clk_g_i;
                #500;
                spi_clk_g_i = ~spi_clk_g_i;
            end
            $display("SPI Read: Address %d, Data %b", i, spi_miso_g_o);
        end
        spi_cs_g_i = 1;
        #10;

        // End simulation
        $finish;
    end

endmodule


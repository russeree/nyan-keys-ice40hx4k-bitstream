/**
 * @auth: Reese Russell
 * @date: 10/10/23
 * @desc: keys -> spi registers
 */

module spi_keys #(parameter NUM_KEYS = 68) (
    // Globals
    output reg led_o,
    input wire clk_g_i,
    input wire rstn_g_i,

    // SPI Interface - Global
    input  wire spi_clk_g_i,
    input  wire spi_mosi_g_i,
    output wire spi_miso_g_o,
    input  wire spi_cs_g_i,

    // Key Interface - Global
    input wire [NUM_KEYS-1:0] keys_i_g
    );

    // Register group properties, groups can not be more than 512
    localparam GROUPS       = (NUM_KEYS + 7) / 8;
    localparam GROUPS_PAD   = (NUM_KEYS % 8);
    localparam GROUPS_WIDTH = $clog2(GROUPS);
    localparam KEYS_PAD     = (GROUPS_PAD == 0) ? NUM_KEYS : NUM_KEYS + (8 - GROUPS_PAD);

    // Internal routes
    wire [NUM_KEYS-1:0]          keys;
    wire [KEYS_PAD-NUM_KEYS-1:0] keys_pad_bits;
    wire [KEYS_PAD-1:0]          keys_pad = {keys_pad_bits, keys};
    wire [7:0]                   keys_bram_mux_o_int;
    wire                         spi_rx_valid;
    wire [7:0]                   spi_rx_byte;

    // Internal registers
    reg [GROUPS_WIDTH-1:0] groups_select;
    reg [7:0]              spi_tx_byte;
    reg [7:0]              spi_synch_ram [0:511];

    // Keyboard keys interface
    keys #(NUM_KEYS) keys_interface (
        .clk_i   (key_clk),
        .rst_n_i (rstn_g_i),
        .keys_i  (keys_i_g),
        .keys_o  (keys)
    );

    // SPI module - slave mode
    mojo_spi_slave spi_slave (
        .rst  (rstn_g_i),
        .clk  (clk_g_i),
        .done (spi_rx_valid),
        .din  (spi_tx_byte),
        .dout (spi_rx_byte),
        .sck  (spi_clk_g_i),
        .miso (spi_miso_g_o),
        .mosi (spi_mosi_g_i),
        .ss   (spi_cs_g_i)
    );

    always @(posedge clk_g_i) begin
        led_o <= 1'b1;
    end

    /**
     * Every clock cycle read from the address that has been locked in
     */
    always @(posedge clk_g_i) begin
        if (spi_rx_valid) begin
            spi_tx_byte <= spi_synch_ram[spi_rx_byte];
        end
    end

    /**
     * Creates a running selection for the mux output into the bram write
     * line. This mux output is the padded regs of keys being broken up into
     * 8 bit chunks. These chunks are addressed into the output of the spi
     * readout from the block ram
     */
    always @(posedge clk_g_i) begin
        if (rstn_g_i == 1'b0) begin
            groups_select <= 1'd0;
        end else if (groups_select == GROUPS - 1) begin
            groups_select <= 1'd0;
        end else begin
            groups_select <= groups_select + 1'b1;
        end
    end

    /**
     * Take the output of the mux and write it to memory each clock cycle
     */
    always @(posedge clk_g_i) begin
        spi_synch_ram[groups_select] <= keys_bram_mux_o_int;
    end

    /**
     *12Mhz to 800hz Frequency Divider
     */
    reg [12:0] counter = 0;
    reg key_clk;
    always @(posedge clk_g_i) begin
        if (counter == 13'd7499) begin // 1 less than our count of 7,500
            key_clk <= ~key_clk;   // Toggle the output clock
            counter <= 0;              // Reset the counter
        end else begin
            counter <= counter + 1;    // Increment the counter
        end
    end

    // Create a mux to the input of the bram
    assign keys_bram_mux_o_int = keys_pad[groups_select*8 +: 8];
    assign keys_pad_bits = {KEYS_PAD-GROUPS-1{1'b0}};

endmodule

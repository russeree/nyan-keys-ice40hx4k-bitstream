/**
 * @auth: Reese Russell
 * @date: 10/10/23
 * @desc: keys -> spi registers
 */

module spi_keys #(parameter NUM_KEYS = 61) (
    // Globals
    input  wire clk_g_i,
    input  wire rstn_g_i,
    output wire keys_valid_o, // Active high valid operations wire.

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

    // Internal clocks
    wire        clk_g_int;
    wire        clk_g_int_buf;
    wire        sdo_int;

    // Internal routes
    wire [NUM_KEYS-1:0]          keys;
    wire [KEYS_PAD-NUM_KEYS-1:0] keys_pad_bits;
    wire [KEYS_PAD-1:0]          keys_pad = {keys_pad_bits, keys};
    wire [7:0]                   keys_bram_mux_o_int;
    wire                         spi_rx_valid;
    wire [7:0]                   spi_rx_byte;
    wire                         pll_locked;

    // Internal registers
    reg [GROUPS_WIDTH-1:0] groups_select;
    reg [7:0]              spi_tx_byte;
    reg [7:0]              spi_synch_ram [0:511];
    reg [17:0]             key_clk_counter = 0;
    reg                    key_clk;
    reg                    keys_valid;

    // Keyboard keys interface
    keys #(NUM_KEYS) keys_interface (
        .clk_i   (clk_g_i),
        .keys_i  (keys_i_g),
        .keys_o  (keys)
    );

    // SPI module - slave mode
    nyan_spi_slave spi_slave (
        .rst  (pll_locked),
        .clk  (clk_g_int_buf),
        .done (spi_rx_valid),
        .din  (spi_tx_byte),
        .dout (spi_rx_byte),
        .sck  (spi_clk_g_i),
        .miso (sdo_int),
        .mosi (spi_mosi_g_i),
        .ss   (spi_cs_g_i)
    );

    /**
     * Simulation stuff
     */
    integer i;
    initial begin
        `ifdef __ICARUS__
            $display("Icarus Verilog is used for simulation.");
            // Initialize only in simulation
            for (i = 0; i < (1<<9); i = i + 1) begin
                spi_synch_ram[i] = 0;
            end
        `endif
    end

    `ifdef __ICARUS__
        /**
         * Simulation bypass PLL - Since no models are available
         */
        assign clk_g_int_buf = clk_g_i;
    `else
        /**
         * Core clock generation - 120MHZ
         */
        SB_PLL40_CORE #(
            .FEEDBACK_PATH("SIMPLE"),
            .DIVR(4'b0000),       // DIVR =  0
            .DIVF(7'b1001111),    // DIVF = 79
            .DIVQ(3'b011),        // DIVQ =  3
            .FILTER_RANGE(3'b001) // FILTER_RANGE = 1
        ) g_pll (
            .LOCK(pll_locked),
            .RESETB(1'b1),
            .BYPASS(1'b0),
            .REFERENCECLK(clk_g_i),
            .PLLOUTGLOBAL(clk_g_int)
        );

        // Buffer the output of the pll before use.
        SB_GB pll_fabric_buffer(
            .USER_SIGNAL_TO_GLOBAL_BUFFER(clk_g_int),
            .GLOBAL_BUFFER_OUTPUT(clk_g_int_buf)
        );
    `endif

    /**
     * Every clock cycle read from the address that has been locked in
     */
    always @(posedge clk_g_int_buf) begin
        if (spi_cs_g_i) begin
            spi_tx_byte <= 8'h00;
        end else begin
            spi_tx_byte <= spi_synch_ram[spi_rx_byte];
        end
    end

    /**
     * Creates a running selection for the mux output into the bram write
     * line. This mux output is the padded regs of keys being broken up into
     * 8 bit chunks. These chunks are addressed into the output of the spi
     * readout from the block ram
     */
    always @(posedge clk_g_int_buf or negedge rstn_g_i) begin
        if (rstn_g_i == 1'b0) begin
            groups_select <= 1'd0;
        end else if (groups_select == GROUPS - 1) begin
            groups_select <= 1'd0;
        end else begin
            groups_select <= groups_select + 1'b1;
        end
    end

    /**
     * Nyan Keys IP is functional and bitstream has been loaded
     */
    always @(posedge clk_g_int_buf) begin
        if (rstn_g_i == 1'b0) begin
            keys_valid = 1'b1;
        end else begin
            keys_valid = 1'b0;
        end
    end

    /**
     * Take the output of the mux and write it to memory each clock cycle
     */
    always @(posedge clk_g_int_buf) begin
        if (spi_rx_valid == 1'b0) begin
            spi_synch_ram[groups_select] <= keys_bram_mux_o_int;
        end
    end

    // Create a mux to the input of the bram
    assign keys_bram_mux_o_int = keys_pad[groups_select*8 +: 8];
    assign keys_pad_bits = {KEYS_PAD-GROUPS-1{1'b0}};
    assign keys_valid_o = keys_valid;
    assign spi_miso_g_o = (spi_cs_g_i) ? 1'bz : sdo_int;

endmodule

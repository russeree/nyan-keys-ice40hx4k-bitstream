/**
 * @auth: Reese Russell
 * @date: 10/10/23
 * @desc: keys -> spi registers
 */

module spi_keys #(parameter NUM_KEYS = 61) (
    // Globals
    input  wire clk_g_i,
    input  wire rstn_g_i,
    input  wire spi_keys_ack,

    // SPI Interface - Global
    output wire spi_clk_g_o,
    output wire spi_mosi_g_o,

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
    wire        spi_tx_ready;

    // Internal routes
    wire [NUM_KEYS-1:0]          keys;
    wire [KEYS_PAD-NUM_KEYS-1:0] keys_pad_bits;
    wire [KEYS_PAD-1:0]          keys_pad = {keys_pad_bits, keys_prv};
    wire [7:0]                   keys_mux;
    wire                         pll_locked;

    // Internal registers
    reg [GROUPS_WIDTH-1:0]  groups_select;
    reg [NUM_KEYS-1:0]      keys_prv;
    reg                     spi_tx_valid;
    reg                     spi_tx_lock;

    // Keyboard keys interface - 92 MHZ/
    keys #(NUM_KEYS) keys_interface (
        .clk_i   (clk_g_i),
        .rst_n_i (rstn_g_i),
        .keys_i  (keys_i_g),
        .keys_o  (keys)
    );

    // SPI module - Master
    SPI_Master #(
        .SPI_MODE(0),
        .CLKS_PER_HALF_BIT(2)
    ) nyan_keys_spi (
        .i_Rst_L   (rstn_g_i),
        .i_Clk     (clk_g_int_buf),
        .i_TX_Byte (keys_mux),
        .i_TX_DV   (spi_tx_valid),
        .o_TX_Ready(spi_tx_ready),
        .o_RX_DV   (),
        .o_SPI_Clk (spi_clk_g_o),
        .i_SPI_MISO(1'b0),
        .o_SPI_MOSI(spi_mosi_g_o)
    );

    /**
     * Simulation Conditions
     */
    `ifdef __ICARUS__
        /**
         * Simulation bypass PLL - Since no models are available
         */
        assign clk_g_int_buf = clk_g_i;
        assign pll_locked = rstn_g_i;
    `else
        /**
         * Core clock generation - 78MHZ
         */
        SB_PLL40_CORE #(
            .FEEDBACK_PATH("SIMPLE"),
            .DIVR(4'b0000),       // DIVR =  0
            .DIVF(7'b0110011),    // DIVF = 51
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
     * Key Refresh Circuit
     *  - This is the key refresh cycle, essentially it forces the
     *    statemachine to obtain a new set of keys regardless of if a change
     *    in the keys_o has occoured. This is infrequent enough to not impact
     *    latency but at the same time is frequent enough to feel responsive
     *    and 
     */
    reg [22:0] refresh_counter;
    localparam refresh_cnt = 22'd3900000;

    always @(posedge clk_g_int_buf or negedge rstn_g_i) begin
        if (!rstn_g_i) begin
            refresh_counter <= 1'b0;
        end else begin
            if ((refresh_counter >= refresh_cnt) || (keys_changed) || (!spi_tx_ready)) begin
                refresh_counter <= 1'b0;
            end else begin
                refresh_counter <= refresh_counter + 1'b1;
            end
        end
    end

    /**
     * MCU to Master; ACK signal
     *  - This is meant to gate the spi connection between master and slave to
     *    ensure the slave never desyncs from the master (Nyan Keys). This is very
     *    important becuase of the fact that the slave does not have any
     *    method to keep track of the order of bytes coming in. If a press is
     *    received after a release or a release is never registered then this
     *    will show up as a stuck key.
     */
    reg spi_ack;

    always @(posedge clk_g_int_buf or negedge rstn_g_i) begin
        if (rstn_g_i == 1'b0) begin
            spi_ack <= 1'b0;
        end else begin
            if ((spi_keys_ack == 1'b1) && (spi_ack == 1'b0)) begin
                spi_ack <= 1'b1;
            end else begin
                if ((keys_spi_state != KEY_SPI_STATE_PROCESS) && (spi_keys_ack == 1'b0)) begin
                    spi_ack <= 1'b0;
                end
            end
        end
    end

    /**
     * On keys change set the keys changed flag and set the keys previous
     * state: Wait until keys cahnge again after the keys changed has been
     * acked.
     */
    reg keys_changed;

    always @(posedge clk_g_int_buf or negedge rstn_g_i) begin
        if (!rstn_g_i) begin
            keys_changed <= 1'b0;
            keys_prv <= {NUM_KEYS{1'b1}};
        end else begin
            if (!keys_changed) begin
                // We either wait for the keys to refresh or activate on the
                // refresh counter
                if((keys_prv != keys) || (refresh_counter == (refresh_cnt - 1'b1))) begin
                    keys_prv <= keys;
                    keys_changed <= 1'b1;
                end
            end else if ((keys_spi_state == KEY_SPI_STATE_DONE) && spi_tx_ready) begin;
                keys_changed <= 1'b0;
            end
        end
    end

    /**
     * SPI master TX Logic - There are a few goals.
     * 1. When the keys state changes, begin a write to the slave
     * 2. During the slave write process lock out key state changes
     * 3. Stop after (n) bytes have transfered over the SPI bus
     */
    reg [2:0] keys_spi_state;
    reg [GROUPS_WIDTH:0] current_byte;

    localparam KEY_SPI_COMPLETE_DELAY = 10'd10;
    localparam KEY_SPI_STATE_IDLE     = 3'b000;
    localparam KEY_SPI_STATE_ACTIVE   = 3'b001;
    localparam KEY_SPI_STATE_SUBMIT   = 3'b010;
    localparam KEY_SPI_STATE_PROCESS  = 3'b011;
    localparam KEY_SPI_STATE_DONE     = 3'b100;

    always @(posedge clk_g_int_buf or negedge rstn_g_i) begin
        if (rstn_g_i == 1'b0) begin
            keys_spi_state <= KEY_SPI_STATE_IDLE;
            groups_select  <= 3'b000;
            current_byte   <= 1'b0;
            spi_tx_valid   <= 1'b0;
            processing_cnt <= 1'b0;
        end else begin
            case (keys_spi_state)
                // Waiting for a key state change to broadcast
                KEY_SPI_STATE_IDLE: begin
                    if (keys_changed && spi_tx_ready) begin
                        groups_select  <= 3'b000;
                        spi_tx_valid   <= 1'b1;
                        spi_tx_lock    <= 1'b1;
                        current_byte   <= 1'b0;
                        processing_cnt <= 1'b0;
                        keys_spi_state <= KEY_SPI_STATE_ACTIVE;
                    end
                end
                // Transfer is active - bulk send bytes
                KEY_SPI_STATE_ACTIVE: begin
                    if (spi_tx_ready) begin
                        spi_tx_valid <= 1'b1;
                        current_byte <= current_byte + 1'b1;
                        keys_spi_state <= KEY_SPI_STATE_SUBMIT;
                    end else begin
                        spi_tx_valid <= 1'b0;
                    end
                end
                // Transfer Submission Logic
                KEY_SPI_STATE_SUBMIT: begin
                    if (spi_tx_ready == 1'b0) begin
                        spi_tx_valid <= 1'b0;
                        if (current_byte < GROUPS) begin
                            groups_select <= groups_select + 1'b1;
                            keys_spi_state <= KEY_SPI_STATE_ACTIVE;
                        end else begin
                            current_byte   <= 1'b0;
                            keys_spi_state <= KEY_SPI_STATE_PROCESS;
                        end
                    end
                end
                KEY_SPI_STATE_PROCESS: begin
                    if (spi_ack == 1'b1) begin
                        keys_spi_state <= KEY_SPI_STATE_DONE;
                    end
                end
                KEY_SPI_STATE_DONE: begin
                    if (spi_tx_ready && spi_ack == 1'b0) begin
                        keys_spi_state <= KEY_SPI_STATE_IDLE;
                    end
                end
                // Default cause should not be reached - If we get here just
                // go to the default state.
                default: begin
                    keys_spi_state <= KEY_SPI_STATE_IDLE;
                end
            endcase
        end
    end

    // Create a mux to the input of the bram
    assign keys_mux = keys_pad[groups_select*8 +: 8];
    assign keys_pad_bits = {KEYS_PAD-GROUPS-1{1'b0}};

endmodule

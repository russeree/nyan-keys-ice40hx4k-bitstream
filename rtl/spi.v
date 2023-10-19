module mojo_spi_slave (
    // SPI signals
    input            ss,
    input            mosi,
    output reg       miso,
    input            sck,
    // FPGA signals
    input            clk,
    input            rst,
    output reg       done,
    input      [7:0] din,
    output reg [7:0] dout
    );

    // Synchros
    reg [1:0] ss_sync;
    reg [1:0] sck_sync;
    reg [1:0] mosi_sync;
    // Edge detectors
    reg       sck_prev;
    // SPI registers
    reg [2:0] bit_cnt;
    reg [7:0] miso_o;
    reg       done_s;     // A latch so that done doesnt oscilate during the SCK high
    reg       loaded_s;   // Data has been loaded in

    /**
     * sck meta stability synchronizer
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ss_sync   <= 2'b00;
            sck_sync  <= 2'b00;
            mosi_sync <= 2'b00;
        end else begin
            ss_sync   <= {ss_sync[0], ss};     // Shift in the incoming SS signal
            sck_sync  <= {sck_sync[0], sck};   // Shift in the incoming SPI clock
            mosi_sync <= {mosi_sync[0], mosi}; // Shift in the incoming MOSI data
        end
    end

    /**
     * Store the current state of the sck to be compared.
     */
    always @(posedge clk or negedge rst) begin
        if (!rst)
            sck_prev <= 1'b0;
        else
            sck_prev <= sck_sync[1];
    end

    /**
     * MOSI sampling and counter
     */
    always @(posedge clk or negedge rst) begin
        if (!rst)
            bit_cnt <= 3'b000;
        else if (ss_sync[1])
            bit_cnt <= 3'b000;
        else if (sck_sync[1] && !sck_prev) begin //Rising Edge - Synced
            bit_cnt <= bit_cnt + 1;
            dout    <= {dout[6:0],mosi_sync[1]};
        end
    end

    /**
     * Latch in the din -> miso_o; to be shifted out on the positive clock
     * signals
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            miso_o <= 8'h00;
            loaded_s <= 1'b0;
        end
        else if (sck_sync[1] && !sck_prev) begin // Rising edge - Synced
            miso_o   <= {miso_o[6:0], 1'b0};
            miso     <= miso_o[7];
            if (bit_cnt != 3'b000) begin
                loaded_s <= 1'b0;
            end
        end else if (!done && done_s && !loaded_s) begin
            miso_o   <= din;
            loaded_s <= 1'b1;
        end
    end

    /**
     * Done signal creation - single clk high signal
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin // general reset
            done   <= 1'b0;
            done_s <= 1'b1;
        end else if (ss_sync[1]) begin // When slave select goes high
            done   <= 1'b0;
            done_s <= 1'b1;
        end else begin // generate the done singal
            if (done == 1'b1)
                done <= 1'b0;
            else if (bit_cnt == 3'b000 && !done_s) begin
                done   <= 1'b1;
                done_s <= 1'b1;
            end else begin
                done <= 1'b0;
                if(bit_cnt != 3'b000)
                    done_s <= 1'b0;
            end
        end
    end

endmodule

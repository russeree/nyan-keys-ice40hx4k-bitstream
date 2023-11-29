module keys #(parameter keys = 61) (
    input                  clk_i,
    input  wire            rst_n_i,
    input  wire [keys-1:0] keys_i,
    output reg  [keys-1:0] keys_o
    );

    // each key is represented by a 7-bit register
    reg [7:0] counter   [keys-1:0];

    integer key;

    // Debouncing Counter - Arm after pin change and counter high
    always @(posedge clk_i) begin
        for (key = 0; key < keys; key = key + 1) begin
            if (rst_n_i == 1'b0) begin
                counter[key] <= 1'b0;
                keys_o[key]  <= 1'b1;
            end else if (counter[key] != 8'hFF) begin
                counter[key] <= counter[key] + 1'b1;
            end else if (keys_o[key] != keys_i[key]) begin
                keys_o[key] <= keys_i[key];
                counter[key] <= 8'h00;
            end
        end
    end

endmodule

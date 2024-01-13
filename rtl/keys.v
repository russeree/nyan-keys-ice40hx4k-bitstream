module keys #(parameter keys = 61) (
    input                  clk_i,
    input  wire [keys-1:0] keys_i,
    output reg  [keys-1:0] keys_o
    );

    reg [21:0]     counter    [keys-1:0];

    integer key;

    // Debouncing logic
    always @(posedge clk_i) begin
        for (key = 0; key < keys; key = key + 1) begin
            if (counter[key] >= 22'd60000) begin
                if (keys_o[key] != keys_i[key]) begin
                    counter[key] <= 22'd0;
                    keys_o[key] <= keys_i[key];
                end
            end else begin
                counter[key] <= counter[key] + 1'b1;
            end
        end
    end

endmodule

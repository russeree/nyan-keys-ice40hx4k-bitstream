module keys #(parameter keys = 89) (
    input             clk_i,
    input             rst_n_i,
    input  [keys-1:0] keys_i,
    output [keys-1:0] keys_o
    );

    // each key is represented by a 2-bit register
    reg [1:0] counter   [keys-1:0];
    reg [0:0] direction [keys-1:0];

    integer key;

    // debouncing counters
    always @(posedge clk_i) begin
        // unroll the key inputs into the counters
        for (key = 0; key < keys; key = key + 1) begin
            if (rst_n_i == 1'b0) begin
                counter[key] <= 1'b0;
            end else if (keys_i[key] == 1'b1 && counter[key] != 2'b11) begin
                counter[key] <= counter[key] + 1'b1;
            end else if (counter[key] != 2'b00) begin
                counter[key] <= counter[key] - 1'b1;
            end
        end
    end

    // keystate logic
    always @(posedge clk_i) begin
        for (key = 0; key < keys; key = key + 1) begin
            if (rst_n_i == 1'b0) begin
                direction[key] <= 1'b1;
            end else if (counter[key] == 2'b00 && direction[key] == 1'b1) begin
                direction[key] <= 1'b0;
            end else if (counter[key] == 2'b11 && direction[key] == 1'b0) begin
                direction[key] <= 1'b1;
            end
        end
    end

    // trace the register outputs to their module outputs
    generate
        genvar trace;
        for(trace = 0; trace < keys; trace = trace + 1) begin
            assign keys_o[trace] = direction[trace];
        end
    endgenerate
endmodule

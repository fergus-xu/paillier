module testbench;
    parameter int WIDTH   = 64;
    parameter int S       = 16;
    parameter int N       = 6;

    logic clk, rst;
    logic start, done;

    logic [WIDTH-1:0] a        [S];
    logic [WIDTH-1:0] b        [S];
    logic [WIDTH-1:0] n        [S];
    logic [WIDTH-1:0] mont_one [S];
    logic [WIDTH-1:0] result   [S];
    logic [WIDTH-1:0] n_prime;

    always #5 clk = ~clk;

    montcios #(
        .WIDTH(WIDTH),
        .S(S),
        .N(N)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mont_start(start),
        .a(a),
        .b(b),
        .p(n),
        .p_prime(n_prime),
        .Tout(result),
        .done(done)
    );

    integer i;
    integer cycle_count;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        cycle_count = 0;

        // Initialize test values
        a[0]        = 32'd262148;   // example value
        b[0]        = 32'd262148;   // example value
        n[0]        = 32'd65793;    // modulus
        mont_one[0] = 32'd65537;
        for (i = 1; i < S; i++) begin
            a[i]        = 32'd0;
            b[i]        = 32'd0;
            n[i]        = 32'd1;
            mont_one[i] = 32'd0;
        end
        n_prime = 32'd4278190335;

        // Reset
        #20 rst = 0;

        // Start multiplication
        #10 start = 1;
        #10 start = 0;

        // Wait and count cycles
        while (!done) begin
            @(posedge clk);
            cycle_count++;
        end

        $display("Montgomery multiplication completed in %0d cycles", cycle_count);
        $display("Result:");
        for (i = 0; i < S; i++) begin
            $display("result[%0d] = %0d", i, result[i]);
        end

        $stop;
    end
endmodule
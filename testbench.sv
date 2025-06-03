module testbench;
    parameter int WIDTH    = 32;
    parameter int R_WIDTH  = 32;
    parameter int EWIDTH   = 8;
    parameter int S        = 8;
    parameter int N        = 3;

    logic clk, rst, start, done;
    logic [WIDTH-1:0] base      [S];
    logic [WIDTH-1:0] n         [S];
    logic [WIDTH-1:0] mont_one  [S];
    logic [R_WIDTH-1:0] n_prime;
    logic [EWIDTH-1:0] exponent;
    logic [WIDTH-1:0] result    [S];

    always #5 clk = ~clk;

    montexp #(.WIDTH(WIDTH), .R_WIDTH(R_WIDTH), .EWIDTH(EWIDTH), .S(S), .N(N)) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .base(base),
        .exponent(exponent),
        .n(n),
        .n_prime(n_prime),
        .mont_one(mont_one),
        .result(result),
        .done(done)
    );

    integer i;
    integer cycle_count;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        cycle_count = 0;

        base[0] = 32'd262148;
        mont_one[0] = 32'd65537;
        n[0] = 32'd65793;

        for (i = 1; i < S; i++) begin
            base[i]      = 32'd0;
            mont_one[i]  = 32'd0;
            n[i]         = 32'd1;
        end

        n_prime = 32'd4278190335;
        exponent = 8'd3;

        // Reset
        #20 rst = 0;

        // Start operation
        #10 start = 1;
        #10 start = 0;

        // Cycle count and monitor

        while (!done) begin
            @(posedge clk);
            cycle_count++;
        end

        wait (done);
        $stop;

    end
endmodule

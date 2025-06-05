module encrypt #(
    parameter int WIDTH    = 32,
    parameter int S        = 8,
    parameter int N        = 3
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,
    input  logic [WIDTH-1:0]      g         [S],  // Montgomery form
    input  logic [WIDTH-1:0]      r         [S],  // Montgomery form
    input  logic [WIDTH-1:0]      n         [S],
    input  logic [WIDTH-1:0]      p_prime,
    input  logic [WIDTH-1:0]      mont_one  [S],
    input  logic [WIDTH-1:0]      message   [S],

    output logic [WIDTH-1:0]      ciphertext[S],
    output logic                  done
);

    localparam int EWIDTH = 2 * S * WIDTH;

    logic                       done_gm, done_rn;
    logic [WIDTH-1:0]           out_gm [S];
    logic [WIDTH-1:0]           out_rn [S];
    logic                       start_gm, start_rn;
    logic [EWIDTH-1:0]          exp_rn;
    logic [EWIDTH-1:0]          exp_gm;

    always_comb begin
        exp_rn = {<<{r}};
        exp_gm = {<<{message}};
    end

    montexp #(.WIDTH(WIDTH), .S(S), .EWIDTH(EWIDTH), .N(N)) exp_gm_unit (
        .clk(clk),
        .rst(rst),
        .start(start),
        .base(g),
        .exponent(exp_gm),
        .modulus(n),
        .p_prime(p_prime),
        .mont_one(mont_one),
        .result(out_gm),
        .done(done_gm)
    );

    montexp #(.WIDTH(WIDTH), .S(S), .EWIDTH(EWIDTH), .N(N)) exp_rn_unit (
        .clk(clk),
        .rst(rst),
        .start(start),
        .base(r),
        .exponent(exp_rn),
        .modulus(n),
        .p_prime(p_prime),
        .mont_one(mont_one),
        .result(out_rn),
        .done(done_rn)
    );

    logic                     mult_start, mult_done;
    logic [WIDTH-1:0]         mult_result [S];

    logic [WIDTH-1:0]         a [S], b [S];
    assign a = out_gm;
    assign b = out_rn;

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) final_mult (
        .clk(clk),
        .rst(rst),
        .mont_start(done_gm && done_rn),
        .a(a),
        .b(b),
        .p(n),
        .p_prime(p_prime),
        .done(mult_done),
        .Tout(mult_result)
    );

    assign ciphertext = mult_result;
    assign done = mult_done;

endmodule

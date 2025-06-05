module paillier_decrypt #(
    parameter int WIDTH = 32,
    parameter int S     = 8,
    parameter int N     = 3
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,

    input  logic [WIDTH-1:0]      ciphertext [S],
    input  logic [WIDTH-1:0]      n         [S],
    input  logic [WIDTH-1:0]      n_squared [2*S],
    input  logic [WIDTH-1:0]      p_prime,
    input  logic [WIDTH-1:0]      mont_one  [2*S],
    input  logic [WIDTH-1:0]      mont_r   [S],
    input  logic [WIDTH-1:0]      lambda    [S],
    input  logic [WIDTH-1:0]      mu        [S],

    output logic [WIDTH-1:0]      message   [S],
    output logic                  done
);

    localparam int EWIDTH = 2 * S * WIDTH;

    typedef enum logic [2:0] {
        IDLE, EXP, REDUCE_U, COMPUTE_L, CONVERT_L, FINAL_MULT, DONE
    } state_t;
    state_t state;

    logic [WIDTH-1:0] u [2*S];
    logic done_exp;
    montexp #(.WIDTH(WIDTH), .S(2*S), .EWIDTH(EWIDTH), .N(N)) exp_u (
        .clk(clk), .rst(rst), .start(start && (state == IDLE)),
        .base(ciphertext), .exponent({<<{lambda}}),
        .modulus(n_squared), .p_prime(p_prime), .mont_one(mont_one),
        .result(u), .done(done_exp)
    );

    logic [WIDTH-1:0] one [2*S];
        initial begin
        one = '{default: '0};
        one[0] = 32'd1;
    end
    logic [WIDTH-1:0] u_norm [2*S];
    logic done_unmont;
    montcios #(.WIDTH(WIDTH), .S(2*S), .N(N)) unmont (
        .clk(clk), .rst(rst), .mont_start(done_exp),
        .a(u), .b(one), .p(n_squared), .p_prime(p_prime),
        .Tout(u_norm), .done(done_unmont)
    );

    // SIMULATION ONLY
    logic [WIDTH-1:0] L [S];
    always_comb begin
        if (state == COMPUTE_L) begin
            longint unsigned u_bigint = 0;
            longint unsigned n_bigint = 0;

            for (int i = 0; i < 2*S; i++) begin
                u_bigint |= longint'(u_norm[i]) << (i * WIDTH);
            end
            for (int i = 0; i < S; i++) begin
                n_bigint |= longint'(n[i]) << (i * WIDTH);
            end

            longint unsigned L_val = (u_bigint - 1) / n_bigint;

            for (int i = 0; i < S; i++) begin
                L[i] = L_val >> (i * WIDTH);
            end
        end
    end

    logic [WIDTH-1:0] L_mont  [S];
    logic [WIDTH-1:0] mu_mont [S];
    logic done_lmont, done_mumont;

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) l_to_mont (
        .clk(clk), .rst(rst), .mont_start(state == CONVERT_L),
        .a(L), .b(mont_r2), .p(n), .p_prime(p_prime),
        .Tout(L_mont), .done(done_lmont)
    );

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) mu_to_mont (
        .clk(clk), .rst(rst), .mont_start(state == CONVERT_L),
        .a(mu), .b(mont_r2), .p(n), .p_prime(p_prime),
        .Tout(mu_mont), .done(done_mumont)
    );

    logic [WIDTH-1:0] prod [S];
    logic done_mult;
    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) mult_final (
        .clk(clk), .rst(rst), .mont_start(done_lmont && done_mumont),
        .a(L_mont), .b(mu_mont), .p(n), .p_prime(p_prime),
        .Tout(prod), .done(done_mult)
    );

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) to_normal (
        .clk(clk), .rst(rst), .mont_start(done_mult),
        .a(prod), .b(one), .p(n), .p_prime(p_prime),
        .Tout(message), .done(done)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:        if (start)       state <= EXP;
                EXP:         if (done_exp)    state <= REDUCE_U;
                REDUCE_U:    if (done_unmont) state <= COMPUTE_L;
                COMPUTE_L:                    state <= CONVERT_L;
                CONVERT_L:   if (done_lmont && done_mumont) state <= FINAL_MULT;
                FINAL_MULT:  if (done_mult)   state <= DONE;
                DONE:                         state <= IDLE;
            endcase
        end
    end

endmodule

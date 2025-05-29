module montcios #(
    parameter int width = 32,
    parameter int S = 4  // number of limbs
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [width-1:0] a [S],
    input  logic [width-1:0] b [S],
    input  logic [width-1:0] p [S],
    input  logic [width-1:0] p_inv,

    output logic [width-1:0] T_out [S+1],
    output logic done
);

    // Internal pipeline registers
    logic [width-1:0] T     [S+1];  // working buffer for T[0:S+1]
    logic [width-1:0] carry [S+1];

    // Pipeline control
    logic [$clog2(2*S+4)-1:0] cycle_cnt;
    logic                    active;
    logic                    valid_pipe [2*S+4];

    // a pipeline register (wavefront delay)
    logic [width-1:0] a_pipe [S+2];
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < S+2; i++) a_pipe[i] <= '0;
        end else if (start) begin
            a_pipe[0] <= a[0];  // first word of a
        end else begin
            for (int i = S+1; i > 0; i--)
                a_pipe[i] <= a_pipe[i-1];
        end
    end

    // control FSM: tracks how many outer loop iterations
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_cnt <= 0;
            active    <= 0;
        end else if (start) begin
            cycle_cnt <= 1;
            active    <= 1;
        end else if (active) begin
            cycle_cnt <= cycle_cnt + 1;
            if (cycle_cnt == (2*S+2)) active <= 0;
        end
    end

    assign done = (cycle_cnt == (2*S+2));

    // Intermediate connections
    logic [width-1:0] T_alpha [S+1];
    logic [width-1:0] C_alpha [S+1];
    logic [width-1:0] a_stages [S];

    logic [width-1:0] T_beta;
    logic [width-1:0] m_beta;

    logic [width-1:0] T_gamma [S+1];
    logic [width-1:0] C_gamma [S+1];

    // ---- α stage ----
    generate
        for (genvar j = 0; j < S; j++) begin : alpha_loop
            alpha_pe #(.width(width)) alpha_inst (
                .clk(clk),
                .rst(rst),
                .valid_in(cycle_cnt >= 1 && cycle_cnt <= S),
                .a_i(a[j]),
                .b_j(b[j]),
                .T_in(T[j]),
                .C_in(carry[j]),
                .T_out(T_alpha[j]),
                .C_out(C_alpha[j]),
                .a_out(a_stages[j]),
                .valid_out()
            );
        end
    endgenerate

    alpha_f_pe #(.width(width)) alpha_final (
        .clk(clk),
        .rst(rst),
        .valid_in(cycle_cnt == S+1),
        .T_s(T[S]),
        .C_in(carry[S]),
        .T_s_out(T_alpha[S]),
        .T_s1_out(T_alpha[S+1]),
        .valid_out()
    );

    // ---- β stage ----
    beta_pe #(.width(width)) beta_inst (
        .clk(clk),
        .rst(rst),
        .valid_in(cycle_cnt == S+2),
        .T0(T_alpha[0]),
        .p0(p[0]),
        .p_inv(p_inv),
        .T0_out(T_beta),
        .m_out(m_beta),
        .valid_out()
    );

    // ---- γ stage ----
    generate
        for (genvar j = 1; j < S; j++) begin : gamma_loop
            gamma_pe #(.width(width)) gamma_inst (
                .clk(clk),
                .rst(rst),
                .valid_in(cycle_cnt >= S+3 && cycle_cnt < 2*S+2),
                .T_j(T_alpha[j]),
                .p_j(p[j]),
                .m(m_beta),
                .C_in(C_alpha[j]),
                .T_jm1_out(T_gamma[j-1]),
                .C_out(C_gamma[j]),
                .valid_out()
            );
        end
    endgenerate

    gamma_f_pe #(.width(width)) gamma_final (
        .clk(clk),
        .rst(rst),
        .valid_in(cycle_cnt == 2*S+2),
        .T_s(T_alpha[S-1]),
        .T_s1(T_alpha[S]),
        .C_in(C_alpha[S]),
        .T_s_1_out(T_gamma[S-1]),
        .T_s_out(T_gamma[S]),
        .valid_out()
    );

    // ---- T_out assignment ----
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < S+1; i++) T_out[i] <= '0;
        end else if (done) begin
            for (int i = 0; i < S+1; i++) T_out[i] <= T_gamma[i];
        end
    end

endmodule

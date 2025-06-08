module gamma_block #(
    parameter int WIDTH = 32,
    parameter int S = 8
)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic start,
    input  logic [WIDTH-1:0] Sin,
    input  logic [WIDTH-1:0] pinv,
    input  logic [WIDTH-1:0] p  [S],

    output logic done,
    output logic [WIDTH-1:0] T_out [S+2]
);

    localparam int LAT = 3;
    logic en_beta, en_gamma, en_gamma_f;
    logic done_beta, done_gamma, done_gamma_f;

    logic [WIDTH-1:0] Cout_b, m;
    logic [WIDTH-1:0] Cout_g, Sout_g;
    logic [WIDTH-1:0] Cout_gf, Sout_gf;

    logic [$clog2(S):0] gamma_idx;
    logic [LAT-1:0] valid_pipe;
    logic [LAT-1:0][$clog2(S)-1:0] addr_pipe;

    logic [$clog2(S+LAT):0] write_count;

    logic [WIDTH-1:0] T [S+2];
    assign T_out = T;

    // === Flush + Start Init ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            for (int i = 0; i < S+2; i++) T[i] <= 0;
            en_beta <= 0;
            en_gamma <= 0;
            en_gamma_f <= 0;
            done_beta <= 0;
            done_gamma <= 0;
            done_gamma_f <= 0;
            gamma_idx <= 0;
            write_count <= 0;
            for (int i = 0; i < LAT; i++) begin
                valid_pipe[i] <= 0;
                addr_pipe[i]  <= 0;
            end
        end else begin
            for (int i = 0; i < S+2; i++) T[i] <= T[i]; // Maintain
        end
    end

    // === Beta Cell ===
    beta #(.WIDTH(WIDTH)) beta_inst (
        .clk(clk),
        .rst(rst),
        .en(en_beta),
        .Sin(T[0]),
        .p0(p[0]),
        .pinv(pinv),
        .Cout(Cout_b),
        .m(m)
    );

    localparam int BETA_LATENCY = 3;
    logic [1:0] beta_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            en_beta      <= 0;
            done_beta    <= 0;
            beta_counter <= 0;
        end else begin
            if (start && !en_beta && !done_beta) begin
                en_beta      <= 1;
                beta_counter <= 0;
            end else if (en_beta) begin
                en_beta <= 0;
            end

            if (!done_beta && beta_counter < BETA_LATENCY)
                beta_counter <= beta_counter + 1;

            if (beta_counter == BETA_LATENCY - 1)
                done_beta <= 1;
        end
    end


    // === Gamma Cell ===
    gamma #(.WIDTH(WIDTH)) gamma_inst (
        .clk(clk),
        .rst(rst),
        .en(en_gamma),
        .Cin(Cout_b),
        .Sin(T[gamma_idx]),
        .m(m),
        .pj(p[gamma_idx]),
        .Cout(Cout_g),
        .Sout(Sout_g)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            for (int i = 0; i < LAT; i++) begin
                valid_pipe[i] <= 0;
                addr_pipe[i]  <= 0;
            end
        end else begin
            valid_pipe[0] <= en_gamma && gamma_idx < S;
            addr_pipe[0]  <= gamma_idx;
            for (int i = 1; i < LAT; i++) begin
                valid_pipe[i] <= valid_pipe[i-1];
                addr_pipe[i]  <= addr_pipe[i-1];
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            gamma_idx <= 0;
            en_gamma <= 0;
            done_gamma <= 0;
        end else begin
            if (done_beta && !en_gamma)
                en_gamma <= 1;

            if (en_gamma && gamma_idx < S) begin
                gamma_idx <= gamma_idx + 1;
            end

            if (valid_pipe[LAT-1] && addr_pipe[LAT-1] < S) begin
                T[addr_pipe[LAT-1]] <= Sout_g;
                write_count <= write_count + 1;
            end

            if (gamma_idx == S)
                en_gamma <= 0;

            if (write_count == S)
                done_gamma <= 1;
        end
    end

    // === Gamma F Cell ===
    gamma_f #(.WIDTH(WIDTH)) gamma_f_inst (
        .clk(clk),
        .rst(rst),
        .en(en_gamma_f),
        .Cin(Cout_g),
        .S1in(T[S]),
        .S2in(T[S+1]),
        .Cout(Cout_gf),
        .Sout(Sout_gf)
    );

    localparam int LATENCY_GF = 2;
    logic [$clog2(LATENCY_GF+1)-1:0] gamma_f_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            en_gamma_f        <= 0;
            done_gamma_f      <= 0;
            gamma_f_counter   <= 0;
        end else begin
            if (done_gamma && !en_gamma_f && !done_gamma_f) begin
                en_gamma_f      <= 1;
                gamma_f_counter <= 0;
            end else if (en_gamma_f) begin
                gamma_f_counter <= gamma_f_counter + 1;
                if (gamma_f_counter == LATENCY_GF - 1) begin
                    en_gamma_f      <= 0;
                    T[S]            <= Cout_gf;
                    T[S-1]          <= Sout_gf;
                    done_gamma_f    <= 1;
                end
            end
        end
    end


    assign done = done_gamma_f;


endmodule

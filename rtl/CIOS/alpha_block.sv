module alpha_block #(
    parameter int WIDTH = 32,
    parameter int S = 8,         // number of limbs
    parameter int N = 3
)(
    input  logic clk,
    input  logic rst,
    input  logic flush, // <== new
    input  logic start,
    input  logic [WIDTH-1:0] a [S],
    input  logic [WIDTH-1:0] b [S],
    input  logic [WIDTH-1:0] p [S],
    input  logic [WIDTH-1:0] p_inv,

    output logic [WIDTH-1:0] T_out [S+2],
    output logic done
);

    localparam int LATENCY = 3;

    logic [$clog2(S):0] idx;
    logic [WIDTH-1:0] T [S+2];
    logic [WIDTH-1:0] Cin, Cout, Sout, Sin;
    logic [WIDTH-1:0] Cin_last;  // <== new capture for alpha_f
    assign Sin = T[idx];
    assign T_out = T;

    logic [WIDTH-1:0] a_in, b_in;
    assign a_in = a[0];
    assign b_in = b[idx];

    // Pipeline registers
    logic [LATENCY-1:0] valid_pipe;
    logic [LATENCY-1:0][$clog2(S)-1:0] addr_pipe;

    logic [$clog2(S+LATENCY):0] write_count;

    logic en_alpha, done_alpha;

    // === Alpha PE ===
    alpha #(.WIDTH(WIDTH)) alpha_inst (
        .clk(clk),
        .rst(rst),
        .en(en_alpha),
        .a(a_in),
        .b(b_in),
        .Cin(Cin),
        .Sin(Sin),
        .Sout(Sout),
        .Cout(Cout)
    );

    // === Carry Chain ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush)
            Cin <= 0;
        else if (en_alpha)
            Cin <= Cout;
    end

    // === Capture Final Cout for Alpha F ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush)
            Cin_last <= 0;
        else if (valid_pipe[LATENCY-1] && addr_pipe[LATENCY-1] == S-1)
            Cin_last <= Cout;
    end

    // === Valid + Addr Pipeline ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            for (int i = 0; i < LATENCY; i++) begin
                valid_pipe[i] <= 0;
                addr_pipe[i]  <= 0;
            end
        end else begin
            valid_pipe[0] <= en_alpha && idx < S;
            addr_pipe[0]  <= idx;
            for (int i = 1; i < LATENCY; i++) begin
                valid_pipe[i] <= valid_pipe[i-1];
                addr_pipe[i]  <= addr_pipe[i-1];
            end
        end
    end

    // === Control Logic ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            idx         <= 0;
            write_count <= 0;
            en_alpha    <= 0;
            done_alpha  <= 0;
            for (int i = 0; i < S+3; i++) T[i] <= 0;
        end else begin
            if (start && !en_alpha)
                en_alpha <= 1;

            if (en_alpha && idx < S)
                idx <= idx + 1;

            if (valid_pipe[LATENCY-1] && addr_pipe[LATENCY-1] < S) begin
                T[addr_pipe[LATENCY-1]] <= Sout;
                write_count <= write_count + 1;
            end

            if (idx == S)
                en_alpha <= 0;

            if (write_count == S)
                done_alpha <= 1;
        end
    end

    // === Alpha F ===
    localparam int LATENCY_AF = 2;
    logic en_alpha_f, done_alpha_f;
    logic [WIDTH-1:0] Sin_af, Cout_af, Sout_af;
    logic [$clog2(LATENCY_AF+1):0] alpha_f_counter;

    assign Sin_af = T[S];

    alpha_f #(.WIDTH(WIDTH)) alpha_f_inst (
        .clk(clk),
        .rst(rst),
        .en(en_alpha_f),
        .Cin(Cin_last),
        .Sin(Sin_af),
        .Sout(Sout_af),
        .Cout(Cout_af)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            en_alpha_f <= 0;
            done_alpha_f <= 0;
            alpha_f_counter <= 0;
        end else begin
            if (done_alpha && !en_alpha_f && !done_alpha_f) begin
                en_alpha_f <= 1;
                alpha_f_counter <= 0;
            end else if (en_alpha_f) begin
                alpha_f_counter <= alpha_f_counter + 1;
                if (alpha_f_counter == LATENCY_AF - 1) begin
                    T[S]     <= Sout_af;
                    T[S+1]   <= Cout_af;
                    en_alpha_f   <= 0;
                    done_alpha_f <= 1;
                end
            end
        end
    end

    assign done = done_alpha_f;

endmodule

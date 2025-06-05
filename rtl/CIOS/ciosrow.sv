module ciosrow #(
    parameter int WIDTH = 32,
    parameter int S     = 8
)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic start,

    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b [S],
    input  logic [WIDTH-1:0] p [S],
    input  logic [WIDTH-1:0] p_prime,

    input  logic [WIDTH-1:0] T [S+2],

    output logic             we,
    output logic [$clog2(S+2)-1:0] waddr,
    output logic [WIDTH-1:0]        wdata,

    output logic done
);

    localparam int LAT = 3;

    // === Alpha Stage ===
    logic [$clog2(S):0] idx;
    logic [LAT-1:0] valid_pipe_alpha;
    logic [LAT-1:0][$clog2(S)-1:0] addr_pipe_alpha;
    logic [$clog2(S+LAT):0] write_count_alpha;
    logic [WIDTH-1:0] Cin, Cout, Sout, Sin;
    logic en_alpha, done_alpha;

    assign Sin = T[idx];

    alpha #(.WIDTH(WIDTH)) alpha_inst (
        .clk(clk), .rst(rst), .en(en_alpha),
        .a(a), .b(b[idx]), .Cin(Cin), .Sin(Sin),
        .Sout(Sout), .Cout(Cout)
    );

    logic start_d;
    logic [1:0] cycle_count;
    logic Cout_valid;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            start_d            <= 0;
            en_alpha           <= 0;
            idx                <= 0;
            Cin                <= 0;
            done_alpha         <= 0;
            Cout_valid         <= 0;
            write_count_alpha  <= 0;
            cycle_count        <= 0;
            for (int i = 0; i < LAT; i++) begin
                valid_pipe_alpha[i] <= 0;
                addr_pipe_alpha[i]  <= 0;
            end
        end else begin
            start_d <= start;

            // Pulse to latch Cout as Cin in the next cycle
            if (Cout_valid)
                Cin <= Cout;

            // Start condition
            if (start_d && !en_alpha) begin
                en_alpha     <= 1;
                idx          <= 0;
                Cin          <= 0;          // reset Cin
                cycle_count  <= 0;
                Cout_valid   <= 0;
            end

            // Pipeline progression
            if (en_alpha) begin
                if (cycle_count == 2) begin
                    cycle_count <= 0;

                    if (idx < S) begin
                        valid_pipe_alpha[0] <= 1;
                        addr_pipe_alpha[0]  <= idx;
                        Cout_valid          <= 1; // flag Cout as valid this cycle
                        idx                 <= idx + 1;
                    end else begin
                        valid_pipe_alpha[0] <= 0;
                        Cout_valid          <= 0;
                    end
                end else begin
                    cycle_count         <= cycle_count + 1;
                    valid_pipe_alpha[0] <= 0;
                    Cout_valid          <= 0;
                end
            end

            // Shift pipeline
            for (int i = 1; i < LAT; i++) begin
                valid_pipe_alpha[i] <= valid_pipe_alpha[i-1];
                addr_pipe_alpha[i]  <= addr_pipe_alpha[i-1];
            end

            // Track writes
            if (valid_pipe_alpha[LAT-1])
                write_count_alpha <= write_count_alpha + 1;

            if (write_count_alpha == S && !done_alpha) begin
                done_alpha <= 1;
                write_count_alpha <= 0;
            end else 
                done_alpha <= 0;

            if (idx == S && !valid_pipe_alpha[0])
                en_alpha <= 0;
        end
    end




    logic we_alpha;
    logic [$clog2(S+2)-1:0] waddr_alpha;
    logic [WIDTH-1:0] wdata_alpha;

    assign we_alpha    = valid_pipe_alpha[LAT-1];
    assign waddr_alpha = addr_pipe_alpha[LAT-1];
    assign wdata_alpha = Sout;

    // === Alpha F Stage ===
    localparam int LAT_AF = 2;
    logic en_alpha_f, done_alpha_f;
    logic [WIDTH-1:0] Sout_af, Cout_af;
    logic [$clog2(LAT_AF+1):0] af_counter;
    logic [WIDTH-1:0] Cin_af;

    logic capture_cout;

    assign capture_cout = (write_count_alpha == S - 1) && valid_pipe_alpha[LAT-1];

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            Cin_af <= 0;
        end else if (capture_cout) begin
            Cin_af <= Cout;
        end
    end


    alpha_f #(.WIDTH(WIDTH)) alpha_f_inst (
        .clk(clk), .rst(rst), .en(en_alpha_f),
        .Cin(Cin_af), .Sin(T[S]),
        .Sout(Sout_af), .Cout(Cout_af)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            en_alpha_f <= 0;
            done_alpha_f <= 0;
            af_counter <= 0;
        end else if (done_alpha && !done_alpha_f && !en_alpha_f) begin
            en_alpha_f <= 1;
            af_counter <= 0;
        end else if (en_alpha_f) begin
            af_counter <= af_counter + 1;
            if (af_counter == LAT_AF && !done_alpha_f) begin
                en_alpha_f <= 0;
                done_alpha_f <= 1;
                af_counter <= 0;
            end
            
        end else
            done_alpha_f <= 0;
    end

    logic we_af;
    logic [$clog2(S+2)-1:0] waddr_af;
    logic [WIDTH-1:0] wdata_af;

    always_comb begin
        we_af = 0;
        waddr_af = 0;
        wdata_af = 0;
        if (en_alpha_f) begin
            if (af_counter == LAT_AF - 1) begin
                we_af = 1;
                waddr_af = S;
                wdata_af = Sout_af;
            end else if (af_counter == LAT_AF) begin
                we_af = 1;
                waddr_af = S + 1;
                wdata_af = Cout_af;
            end
        end
    end

    // === Beta Stage ===
    localparam int LAT_B = 3;
    logic en_beta, done_beta;
    logic [WIDTH-1:0] m, Cout_b;
    logic [$clog2(LAT_B+1):0] beta_counter;

    beta #(.WIDTH(WIDTH)) beta_inst (
        .clk(clk), .rst(rst), .en(en_beta),
        .Sin(T[0]), .p0(p[0]), .p_prime(p_prime),
        .Cout(Cout_b), .m(m)
    );

    always_ff @(posedge clk or posedge rst) begin
    if (rst || flush) begin
        en_beta <= 0;
        beta_counter <= 0;
        done_beta <= 0;
    end else begin
        // Start beta exactly when idx == 1 (i.e., after first alpha finishes)
        if (en_alpha && idx == 2 && !en_beta) begin
            en_beta <= 1;
            beta_counter <= 0;
        end else if (en_beta) begin
            beta_counter <= beta_counter + 1;
            if (beta_counter == LAT_B - 1)
                done_beta <= 1;
            if (beta_counter == LAT_B)
                en_beta <= 0;
        end else begin
            done_beta <= 0; // Reset for next cycle
        end
    end
    end

    // === Gamma Stage ===
    logic [$clog2(S):0] gamma_idx;
    logic [LAT-1:0] valid_pipe_gamma;
    logic [LAT-1:0][$clog2(S)-1:0] addr_pipe_gamma;
    logic [$clog2(S+LAT):0] write_count_gamma;
    logic en_gamma, done_gamma;
    logic [WIDTH-1:0] Sout_g, Cout_g;

    logic [WIDTH-1:0] gamma_cin;
    logic first_gamma;

    // Track if it's the first gamma iteration
    assign first_gamma = (gamma_idx == 1);

    // Select carry-in source
    assign gamma_cin = first_gamma ? Cout_b : Cout_g;

    gamma #(.WIDTH(WIDTH)) gamma_inst (
        .clk(clk), .rst(rst), .en(en_gamma),
        .Cin(gamma_cin), .Sin(T[gamma_idx]),
        .m(m), .pj(p[gamma_idx]),
        .Sout(Sout_g), .Cout(Cout_g)
    );


    logic [1:0] gamma_cycle_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            gamma_idx         <= 1;
            en_gamma          <= 0;
            done_gamma        <= 0;
            write_count_gamma <= 0;
            gamma_cycle_count <= 0;
            for (int i = 0; i < LAT; i++) begin
                valid_pipe_gamma[i] <= 0;
                addr_pipe_gamma[i]  <= 0;
            end
        end else begin
            if (done_beta && !en_gamma) begin
                en_gamma          <= 1;
                gamma_idx         <= 1;
                gamma_cycle_count <= 0;
            end

            if (en_gamma) begin
                if (gamma_cycle_count == 2) begin  // every 3rd cycle
                    gamma_cycle_count <= 0;

                    if (gamma_idx < S) begin
                        valid_pipe_gamma[0] <= 1;
                        addr_pipe_gamma[0]  <= gamma_idx;
                        gamma_idx           <= gamma_idx + 1;
                    end else begin
                        valid_pipe_gamma[0] <= 0;
                    end
                end else begin
                    gamma_cycle_count <= gamma_cycle_count + 1;
                    valid_pipe_gamma[0] <= 0;  // don't pulse on off cycles
                end
            end

            for (int i = 1; i < LAT; i++) begin
                valid_pipe_gamma[i] <= valid_pipe_gamma[i-1];
                addr_pipe_gamma[i]  <= addr_pipe_gamma[i-1];
            end

            if (valid_pipe_gamma[LAT-1])
                write_count_gamma <= write_count_gamma + 1;

            if (write_count_gamma == S - 1 && !done_gamma) begin
                done_gamma <= 1;
                write_count_gamma <= 0;
                en_gamma <= 0;
            end else 
                done_gamma <= 0;
        end
    end


    logic we_gamma;
    logic [$clog2(S+2)-1:0] waddr_gamma;
    logic [WIDTH-1:0] wdata_gamma;

    assign we_gamma    = valid_pipe_gamma[LAT-1];
    assign waddr_gamma = addr_pipe_gamma[LAT-1] - 1;
    assign wdata_gamma = Sout_g;

    logic [WIDTH-1:0] Cin_gf;
    logic capture_gamma_cout;
    assign capture_gamma_cout = (write_count_gamma == S - 2) && valid_pipe_gamma[LAT-1];

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            Cin_gf <= 0;
        end else if (capture_gamma_cout) begin
            Cin_gf <= Cout_g;
        end
    end

    // === Gamma F Stage ===
    localparam int LAT_GF = 2;
    logic en_gamma_f, done_gamma_f;
    logic [$clog2(LAT_GF+1):0] gamma_f_counter;
    logic [WIDTH-1:0] Sout_gf, Cout_gf;

    gamma_f #(.WIDTH(WIDTH)) gamma_f_inst (
        .clk(clk), .rst(rst), .en(en_gamma_f),
        .Cin(Cin_gf), .S1in(T[S]), .S2in(T[S+1]),
        .Sout(Sout_gf), .Cout(Cout_gf)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            en_gamma_f <= 0;
            done_gamma_f <= 0;
            gamma_f_counter <= 0;
        end else if (done_gamma && !done_gamma_f && !en_gamma_f) begin
            en_gamma_f <= 1;
            gamma_f_counter <= 0;
        end else if (en_gamma_f) begin
            gamma_f_counter <= gamma_f_counter + 1;
            if (gamma_f_counter == LAT_GF - 1)
                done_gamma_f <= 1;
            if (gamma_f_counter == LAT_GF)
                en_gamma_f <= 0;
        end else
            done_gamma_f <= 0;
    end

    logic we_gf;
    logic [$clog2(S+2)-1:0] waddr_gf;
    logic [WIDTH-1:0] wdata_gf;

    always_comb begin
        we_gf = 0;
        waddr_gf = 0;
        wdata_gf = 0;
        if (en_gamma_f) begin
            if (gamma_f_counter == LAT_GF - 2) begin
                we_gf = 1;
                waddr_gf = S - 1;
                wdata_gf = Sout_gf;
            end else if (gamma_f_counter == LAT_GF - 1) begin
                we_gf = 1;
                waddr_gf = S;
                wdata_gf = Cout_gf;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush)
            done <= 0;
        else if (done_gamma_f)
            done <= 1;
        else
            done <= 0;
    end

    localparam int WRITE_QUEUE_DEPTH = 16;
    localparam int WRITE_QUEUE_IDX_W = $clog2(WRITE_QUEUE_DEPTH);

    typedef struct packed {
        logic [$clog2(S+2)-1:0] addr;
        logic [WIDTH-1:0]       data;
    } write_entry_t;

    write_entry_t write_queue [WRITE_QUEUE_DEPTH];
    logic         queue_valid [WRITE_QUEUE_DEPTH];
    logic [WRITE_QUEUE_IDX_W-1:0] wr_head, wr_tail;

    function automatic logic [WRITE_QUEUE_IDX_W-1:0] incr(input logic [WRITE_QUEUE_IDX_W-1:0] val);
        return (val == WRITE_QUEUE_DEPTH - 1) ? 0 : val + 1;
    endfunction

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            wr_tail <= 0;
            for (int i = 0; i < WRITE_QUEUE_DEPTH; i++)
                queue_valid[i] <= 0;
        end else begin
            if (we_alpha && incr(wr_tail) != wr_head) begin
                write_queue[wr_tail].addr <= waddr_alpha;
                write_queue[wr_tail].data <= wdata_alpha;
                queue_valid[wr_tail] <= 1;
                wr_tail <= incr(wr_tail);
            end

            if (we_af && incr(wr_tail) != wr_head) begin
                write_queue[wr_tail].addr <= waddr_af;
                write_queue[wr_tail].data <= wdata_af;
                queue_valid[wr_tail] <= 1;
                wr_tail <= incr(wr_tail);
            end

            if (we_gamma && incr(wr_tail) != wr_head) begin
                write_queue[wr_tail].addr <= waddr_gamma;
                write_queue[wr_tail].data <= wdata_gamma;
                queue_valid[wr_tail] <= 1;
                wr_tail <= incr(wr_tail);
            end

            if (we_gf && incr(wr_tail) != wr_head) begin
                write_queue[wr_tail].addr <= waddr_gf;
                write_queue[wr_tail].data <= wdata_gf;
                queue_valid[wr_tail] <= 1;
                wr_tail <= incr(wr_tail);
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            wr_head <= 0;
            we      <= 0;
            waddr   <= 0;
            wdata   <= 0;
        end else begin
            we <= 0;
            if (queue_valid[wr_head]) begin
                we    <= 1;
                waddr <= write_queue[wr_head].addr;
                wdata <= write_queue[wr_head].data;
                queue_valid[wr_head] <= 0;
                wr_head <= incr(wr_head);
            end
        end
    end





endmodule

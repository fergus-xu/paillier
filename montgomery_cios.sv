module montgomery_cios #(
    parameter W = 8,
    parameter S = 2
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input logic [W-1:0] a_0, a_1,
    input logic [W-1:0] b_0, b_1,
    input logic [W-1:0] m_0, m_1,
    output logic [W-1:0] result_0, result_1,
    input  logic [W-1:0] m_prime,
    output logic done
);

    typedef enum logic [3:0] {
        IDLE, LOAD,
        OUTER_LOOP,
        INNER_ACCUM, FINAL_ACCUM,
        REDUCE_PREP, REDUCE_INNER, REDUCE_FINAL,
        FINAL_COMPARE, FINAL_SUB, WRITE_RESULT,
        DONE
    } state_t;

    state_t state, next_state;

    logic [W-1:0] A_reg [S], B_reg [S], M_reg [S];
    logic [W-1:0] T [0:S];  // S+1 entries: 0..S

    logic [$clog2(S)-1:0] i;
    logic [$clog2(S+1)-1:0] j;  // safe for T[0:S]
    logic [$clog2(S)-1:0] j_trunc;

    logic [2*W-1:0] mul_tmp;
    logic [W:0] add_tmp;
    logic [W:0] carry_ext;
    logic [W-1:0] u;
    logic [2*W-1:0] reduce_tmp;
    logic gt_flag;

    always_comb begin
        A_reg[0] = a_0; A_reg[1] = a_1;
        B_reg[0] = b_0; B_reg[1] = b_1;
        M_reg[0] = m_0; M_reg[1] = m_1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        unique case (state)
            IDLE:           if (start) next_state = LOAD;
            LOAD:           next_state = OUTER_LOOP;
            OUTER_LOOP:     next_state = INNER_ACCUM;
            INNER_ACCUM:    next_state = (j == S)     ? FINAL_ACCUM   : INNER_ACCUM;
            FINAL_ACCUM:    next_state = REDUCE_PREP;
            REDUCE_PREP:    next_state = REDUCE_INNER;
            REDUCE_INNER:   next_state = (j == S)     ? REDUCE_FINAL  : REDUCE_INNER;
            REDUCE_FINAL:   next_state = (i == $clog2(S)'(S - 1)) ? FINAL_COMPARE : OUTER_LOOP;
            FINAL_COMPARE:  next_state = FINAL_SUB;
            FINAL_SUB:      next_state = WRITE_RESULT;
            WRITE_RESULT:   next_state = DONE;
            DONE:           next_state = IDLE;
            default:        next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0; j <= 0; done <= 0; carry_ext <= 0;
            for (int k = 0; k <= S; k++) T[k] <= 0;
        end else begin
            done <= 0;
            j_trunc = j[$clog2(S)-1:0];  // safe truncation for indexing A/B/M
            case (state)
                LOAD: begin
                    for (int k = 0; k < S; k++) T[k] <= 0;
                    T[S] <= 0;
                    i <= 0;
                    j <= 0;
                end

                OUTER_LOOP: begin
                    carry_ext <= 0;
                    mul_tmp <= A_reg[i] * B_reg[0];
                    add_tmp = {1'b0, T[0]} + mul_tmp[W-1:0];
                    T[0] <= add_tmp[W-1:0];
                    carry_ext <= {{W{1'b0}}, add_tmp[W]};
                    j <= 1;
                end

                INNER_ACCUM: begin
                    mul_tmp <= A_reg[i] * B_reg[j_trunc];
                    add_tmp = {1'b0, T[j]} + mul_tmp[W-1:0] + carry_ext;
                    T[j - 1] <= add_tmp[W-1:0];
                    carry_ext <= {{W{1'b0}}, add_tmp[W]};
                    j <= j + 1;
                end

                FINAL_ACCUM: begin
                    add_tmp = {1'b0, T[S-1]} + carry_ext;
                    T[S-1] <= add_tmp[W-1:0];
                    T[S] <= {{(W-1){1'b0}}, add_tmp[W]};
                    j <= 0;
                end

                REDUCE_PREP: begin
                    u <= T[0] * m_prime;
                    carry_ext <= 0;
                end

                REDUCE_INNER: begin
                    reduce_tmp = u * M_reg[j_trunc];
                    add_tmp = {1'b0, T[j]} + reduce_tmp[W-1:0] + carry_ext;
                    T[j] <= add_tmp[W-1:0];
                    carry_ext <= {{W{1'b0}}, add_tmp[W]};
                    j <= j + 1;
                end

                REDUCE_FINAL: begin
                    add_tmp = {1'b0, T[S]} + carry_ext;
                    for (int k = 0; k < S; k++)
                        T[k] <= T[k+1];
                    T[S-1] <= add_tmp[W-1:0];
                    T[S] <= '0;  // Zero the top word explicitly
                    i <= i + 1;
                    j <= 0;
                end

                FINAL_COMPARE: begin
                    gt_flag <= 0;
                    for (int k = S-1; k >= 0; k--) begin
                        if (T[k] > M_reg[k]) gt_flag <= 1;
                        else if (T[k] < M_reg[k]) gt_flag <= 0;
                    end
                end

                FINAL_SUB: begin
                    for (int k = 0; k < S; k++) begin
                        logic [W-1:0] tmp;
                        tmp = gt_flag ? (T[k] - M_reg[k]) : T[k];
                        case (k)
                            0: result_0 <= tmp;
                            1: result_1 <= tmp;
                            2: result_2 <= tmp;
                            3: result_3 <= tmp;
                        endcase
                    end
                end

                WRITE_RESULT: begin
                    done <= 1;
                end

                default: ;
            endcase
        end
    end
endmodule

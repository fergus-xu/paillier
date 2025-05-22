module montgomery_cios #(
    parameter W = 32,
    parameter S = 8  // number of w-bit words; WIDTH = W*S
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [W-1:0] a [S],
    input  logic [W-1:0] b [S],
    input  logic [W-1:0] m [S],
    input  logic [W-1:0] m_prime,
    output logic [W-1:0] result [S],
    output logic done
);

    typedef enum logic [3:0] {
        IDLE, LOAD,
        OUTER_LOOP_START,
        INNER_MUL_CALC, INNER_MUL_ACCUM, INNER_MUL_NEXT,
        REDUCE_CALC_U, REDUCE_INNER_CALC, REDUCE_ACCUM, REDUCE_SHIFT,
        FINAL_COMPARE, FINAL_SUB, WRITE_RESULT,
        DONE
    } state_t;

    state_t state, next_state;

    logic [W-1:0] A_reg [S], B_reg [S], M_reg [S];
    logic [W-1:0] T [0:S];  // S+1 words

    logic [$clog2(S)-1:0] i, j;
    logic [$clog2(S+1)-1:0] t_index;

    logic [2*W-1:0] mul_tmp;
    logic [W:0] add_tmp;

    logic [W-1:0] u;
    logic [2*W-1:0] reduce_mul;
    logic [W-1:0] carry;
    logic gt_flag;
    logic [W-1:0] T_tmp;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        unique case (state)
            IDLE:               if (start) next_state = LOAD;
            LOAD:               next_state = OUTER_LOOP_START;
            OUTER_LOOP_START:   next_state = INNER_MUL_CALC;
            INNER_MUL_CALC:     next_state = INNER_MUL_ACCUM;
            INNER_MUL_ACCUM:    next_state = (j == $clog2(S)'(S - 1)) ? REDUCE_CALC_U : INNER_MUL_NEXT;
            INNER_MUL_NEXT:     next_state = INNER_MUL_CALC;
            REDUCE_CALC_U:      next_state = REDUCE_INNER_CALC;
            REDUCE_INNER_CALC:  next_state = REDUCE_ACCUM;
            REDUCE_ACCUM:       next_state = (j == $clog2(S)'(S - 1)) ? REDUCE_SHIFT : REDUCE_INNER_CALC;
            REDUCE_SHIFT:       next_state = (i == $clog2(S)'(S - 1)) ? FINAL_COMPARE : OUTER_LOOP_START;
            FINAL_COMPARE:      next_state = FINAL_SUB;
            FINAL_SUB:          next_state = WRITE_RESULT;
            WRITE_RESULT:       next_state = DONE;
            DONE:               next_state = IDLE;
            default:            next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0; j <= 0; t_index <= 0;
            done <= 0;
            for (int k = 0; k <= S; k++) T[k] <= 0;
        end else begin
            done <= 0;
            case (state)
                LOAD: begin
                    for (int k = 0; k < S; k++) begin
                        A_reg[k] <= a[k];
                        B_reg[k] <= b[k];
                        M_reg[k] <= m[k];
                        T[k]     <= 0;
                    end
                    T[S] <= 0;
                    i <= 0;
                    j <= 0;
                    t_index <= 0;
                end

                OUTER_LOOP_START: begin
                    j <= 0;
                    carry <= 0;
                end

                INNER_MUL_CALC: begin
                    mul_tmp <= A_reg[j] * B_reg[i];
                end

                INNER_MUL_ACCUM: begin
                    t_index <= $clog2(S+1)'(j);
                    add_tmp = {1'b0, T[t_index]} + mul_tmp[W-1:0] + carry;
                    T_tmp = add_tmp[W-1:0];
                    carry <= add_tmp[W-1:0];
                    T[t_index] <= T_tmp;
                end

                INNER_MUL_NEXT: begin
                    j <= j + 1;
                end

                REDUCE_CALC_U: begin
                    u <= T[0] * m_prime;
                    j <= 0;
                    carry <= 0;
                end

                REDUCE_INNER_CALC: begin
                    reduce_mul <= u * M_reg[j];
                end

                REDUCE_ACCUM: begin
                    t_index <= $clog2(S+1)'(j);
                    add_tmp = {1'b0, T[t_index]} + reduce_mul[W-1:0] + carry;
                    T[t_index] <= add_tmp[W-1:0];
                    carry <= add_tmp[W-1:0];
                    j <= j + 1;
                end

                REDUCE_SHIFT: begin
                    T[S] <= T[S] + carry;
                    for (int k = 0; k < S; k++) begin
                        T[k] <= T[k+1];
                    end
                    T[S] <= 0;
                    i <= i + 1;
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
                        result[k] <= gt_flag ? (T[k] - M_reg[k]) : T[k];
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

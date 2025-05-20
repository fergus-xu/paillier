module montmult #(
    parameter WIDTH = 8,
    parameter R_WIDTH = 8
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              start,
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    input  logic [WIDTH-1:0]  n,
    input  logic [R_WIDTH-1:0] n_prime,

    output logic [WIDTH-1:0]  result,
    output logic              done
);

    typedef enum logic [2:0] {
        IDLE,
        CALC_T,
        CALC_M,
        CALC_T_PLUS_MN,
        DIVIDE_R,
        FINAL_SUB,
        DONE
    } state_t;

    state_t state;

    logic [2*WIDTH-1:0] T, mN;
    logic [WIDTH-1:0] m, t;
    logic [WIDTH-1:0] result_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            done       <= 0;
            result_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC_T;
                    end
                end

                CALC_T: begin
                    T     <= a * b;
                    state <= CALC_M;
                end

                CALC_M: begin
                    m <= {{(WIDTH - R_WIDTH){1'b0}}, {(T * n_prime)}[R_WIDTH-1:0]};
                    state <= CALC_T_PLUS_MN;
                end

                CALC_T_PLUS_MN: begin
                    mN    <= m * n;
                    state <= DIVIDE_R;
                end

                DIVIDE_R: begin
                    t     <= {T+mN}[WIDTH+R_WIDTH-1:R_WIDTH];
                    state <= FINAL_SUB;
                end

                FINAL_SUB: begin
                    if (t >= n)
                        result_reg <= t - n;
                    else
                        result_reg <= t;
                    state <= DONE;
                end

                DONE: begin
                    done  <= 1;
                    result <= result_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

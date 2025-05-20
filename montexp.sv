module montexp #(
    parameter int WIDTH    = 8,
    parameter int R_WIDTH  = 8,
    parameter int EWIDTH   = 8
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              start,
    input  logic [WIDTH-1:0]  base,
    input  logic [EWIDTH-1:0] exponent,
    input  logic [WIDTH-1:0]  n,
    input  logic [R_WIDTH-1:0] n_prime,
    input  logic [WIDTH-1:0]  mont_one,

    output logic [WIDTH-1:0]  result,
    output logic              done
);

    typedef enum logic [3:0] {
        IDLE,
        INIT,
        SET_MULTIPLY, START_MULTIPLY, WAIT_MULTIPLY,
        SET_SQUARE,   START_SQUARE,   WAIT_SQUARE,
        DONE
    } state_t;

    state_t state;

    // Internal variables
    logic [WIDTH-1:0] a, b;
    logic [WIDTH-1:0] mult_result;
    logic             mult_start, mult_done;

    montmult #(.WIDTH(WIDTH), .R_WIDTH(R_WIDTH)) mult (
        .clk(clk),
        .rst(rst),
        .start(mult_start),
        .a(a),
        .b(b),
        .n(n),
        .n_prime(n_prime),
        .result(mult_result),
        .done(mult_done)
    );

    logic [WIDTH-1:0]  base_reg, result_reg;
    logic [EWIDTH-1:0] exp_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            done        <= 0;
            mult_start  <= 0;
            result      <= 0;
        end else begin
            mult_start <= 0; // default: one-cycle pulse

            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        base_reg   <= base;
                        result_reg <= mont_one;
                        exp_reg    <= exponent;
                        state      <= INIT;
                    end
                end

                INIT: begin
                    if (exp_reg == 0) begin
                        result <= result_reg;
                        done   <= 1;
                        state  <= IDLE;
                    end else if (exp_reg[0]) begin
                        state <= SET_MULTIPLY;
                    end else begin
                        state <= SET_SQUARE;
                    end
                end

                // MULTIPLY path
                SET_MULTIPLY: begin
                    a     <= result_reg;
                    b     <= base_reg;
                    state <= START_MULTIPLY;
                end

                START_MULTIPLY: begin
                    mult_start <= 1;
                    state      <= WAIT_MULTIPLY;
                end

                WAIT_MULTIPLY: begin
                    if (mult_done) begin
                        result_reg <= mult_result;
                        state <= (exp_reg == 0) ? DONE : SET_SQUARE;
                    end
                end

                // SQUARE path
                SET_SQUARE: begin
                    a     <= base_reg;
                    b     <= base_reg;
                    state <= START_SQUARE;
                end

                START_SQUARE: begin
                    mult_start <= 1;
                    state      <= WAIT_SQUARE;
                end

                WAIT_SQUARE: begin
                    if (mult_done) begin
                        base_reg <= mult_result;
                        exp_reg <= exp_reg >> 1;
                        state <= INIT;
                    end
                end

                DONE: begin
                    result <= result_reg;
                    done   <= 1;
                    state  <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

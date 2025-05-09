module montexp #(
    parameter WIDTH=1024
    parameter EWIDTH=1024
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [WIDTH-1:0]  base,
    input logic [EWIDTH-1:0] exponent,
    input logic [WIDTH-1:0]  modulus,
    input logic [WIDTH-1:0]  n_prime,
    input logic [WIDTH-1:0]  mont_one,

    output logic [WIDTH-1:0] result,
    output logic done
)

    typedef enum logic [2:0] {
        IDLE, INIT, MULTIPLY, WAIT_MULTIPLY, SQUARE, WAIT_SQUARE, FINISH
    } state_t;
    state_t state;

    // modular multiplication variables
    logic [WIDTH-1:0] a, b;
    logic [WIDTH-1:0] mult_result;
    logic mult_start, mult_done;

    montmult(.clk(clk), .rst(rst), .start(mult_start), .a(a), .b(b), .n(modulus), .n_prime(n_prime), .result(mult_result), .done(mult_done));

    logic [WIDTH-1:0] base_reg, result_reg;
    logic [EWIDTH-1:0] exp_reg;

    always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= IDLE;
        done       <= 0;
        mult_start <= 0;
    end else begin
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
                    state <= FINISH;
                end else if (exp_reg[0]) begin
                    state <= MULTIPLY;  // go to multiply
                end else begin
                    state <= SQUARE;    // go to square
                end
            end

            MULTIPLY: begin
                mult_start <= 1;
                a          <= result_reg;
                b          <= base_reg;
                state      <= WAIT_MULTIPLY;
            end

            WAIT_MULTIPLY: begin
                if (mult_done) begin
                    result_reg <= mult_result;
                    mult_start <= 0;
                    
                    if ((exp_reg >> 1) == 0) begin
                        state <= FINISH;
                    end else begin
                        state <= SQUARE;
                    end
                end
            end

            SQUARE: begin
                mult_start <= 1;
                a          <= base_reg;
                b          <= base_reg;
                state      <= WAIT_SQUARE;
            end

            WAIT_SQUARE: begin
                if (mult_done) begin
                    base_reg   <= mult_result;
                    exp_reg    <= exp_reg >> 1;
                    mult_start <= 0;

                    if (exp_reg == 1) begin
                        state <= FINISH;
                    end else begin
                        state <= INIT;
                    end
                end
            end

            FINISH: begin
                result <= result_reg;
                done   <= 1;
                state  <= IDLE;
            end
        endcase
    end
end

endmodule
module montexp #(
    parameter WIDTH=1024
    parameter EWIDTH=1024
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [WIDTH-1:0]  base,
    input logic [EWIDTH-1:0] exponent
    input logic [WIDTH-1:0]  modulus,
    input logic [WIDTH-1:0]  n_prime,

    output logic [WIDTH-1:0] result,
    output logic done
)

    typedef enum logic [2:0] {
        IDLE, INIT, SQUARE, MULTIPLY, UPDATE, FINISH
    } state_t;
    state_t state;

    // modular multiplication variables
    logic [WIDTH-1:0] a, b, n_prime;
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
                    result_reg <= 1;    // R mod N if Montgomery, 1 otherwise
                    exp_reg    <= exponent;
                    state      <= INIT;
                end
            end

            INIT: begin
                if (exp_reg == 0) begin
                    state <= FINISH;
                end else if (exp_reg[0]) begin
                    a         <= result_reg;
                    b         <= base_reg;
                    mult_start <= 1;
                    state     <= MULTIPLY;
                end else begin
                    a         <= base_reg;
                    b         <= base_reg;
                    mult_start <= 1;
                    state     <= SQUARE;
                end
            end

            MULTIPLY: begin
                if (mult_done) begin
                    result_reg <= mult_result;
                    mult_start <= 0;
                    a          <= base_reg;
                    b          <= base_reg;
                    mult_start <= 1;
                    state      <= SQUARE;
                end
            end

            SQUARE: begin
                if (mult_done) begin
                    base_reg   <= mult_result;
                    exp_reg    <= exp_reg >> 1;
                    mult_start <= 0;
                    state      <= INIT;
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
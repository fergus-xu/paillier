module montmult #(
    parameter int WIDTH = 1024
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [WIDTH-1:0] a_bar,     // ¯a: input operand in Montgomery domain
    input  logic [WIDTH-1:0] b_bar,     // ¯b: input operand in Montgomery domain
    input  logic [WIDTH-1:0] n,         // n: modulus
    input  logic [WIDTH-1:0] n_prime,   // n′ = -n⁻¹ mod R, R = 2^WIDTH

    output logic [WIDTH-1:0] result,    // output: (ā * b̄ * R⁻¹) mod n
    output logic done
);
    // Issue with variable widths
    // Internal variables following MonPro algorithm notation:
    // Step 1. t := ā · b̄
    logic [2*WIDTH-1:0] t;

    // Step 2. m := (t * n′) mod R
    logic [WIDTH-1:0] m;

    // Step 3. u := (t + m · n) / R
    logic [2*WIDTH-1:0] u;

    // FSM control
    typedef enum logic [1:0] {
        IDLE, CALC_T, CALC_U, REDUCE
    } state_t;

    state_t state, next_state;

    // Sequential state update
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;
        end else begin
            state <= next_state;
        end
    end

    // FSM and computation logic
    always_ff @(posedge clk) begin
        case (state)
            // Wait for start pulse
            IDLE: begin
                done <= 0;
                if (start) begin
                    // Step 1: t := ā · b̄
                    t <= a_bar * b_bar;
                    next_state <= CALC_T;
                end
            end

            // Compute m and u
            CALC_T: begin
                // Step 2: m := (t * n′) mod R
                // Since R = 2^WIDTH, mod R = truncate to lower WIDTH bits
                m <= (t[WIDTH-1:0] * n_prime) & {WIDTH{1'b1}};

                // Step 3: u := (t + m * n) / R
                // Divide by R = 2^WIDTH is implemented as right shift
                u <= (t + m * n) >> WIDTH;

                next_state <= CALC_U;
            end

            // Final reduction if u ≥ n
            CALC_U: begin
                // Step 4: if u ≥ n then return u − n else return u
                if (u >= n)
                    result <= u - n;
                else
                    result <= u;

                next_state <= REDUCE;
            end

            REDUCE: begin
                done <= 1;
                next_state <= IDLE;
            end
        endcase
    end

endmodule


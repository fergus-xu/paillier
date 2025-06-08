module montexp #(
    parameter int WIDTH    = 32,
    parameter int S        = 8,    // number of limbs (words)
    parameter int EWIDTH   = 256,  // exponent bit width
    parameter int N        = 3     // for montcios internal depth
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,
    input  logic [WIDTH-1:0]      base     [S],
    input  logic [EWIDTH-1:0]     exponent,
    input  logic [WIDTH-1:0]      modulus  [S],
    input  logic [WIDTH-1:0]      p_prime,
    input  logic [WIDTH-1:0]      mont_one [S],

    output logic [WIDTH-1:0]      result   [S],
    output logic                  done
);

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        MULT1_START, MULT1_WAIT,
        MULT2_START, MULT2_WAIT,
        FINALIZE
    } state_t;

    state_t state;

    // Registers
    logic [WIDTH-1:0] R0 [S];  // accumulator
    logic [WIDTH-1:0] R1 [S];  // base
    logic [WIDTH-1:0] a  [S], b [S], Tout [S];

    logic             mont_start, mont_done;
    logic [EWIDTH-1:0] exp_reg;
    logic              current_bit;

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) mult (
        .clk(clk),
        .rst(rst),
        .mont_start(mont_start),
        .a(a),
        .b(b),
        .p(modulus),
        .p_prime(p_prime),
        .done(mont_done),
        .Tout(Tout)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            done        <= 0;
            mont_start  <= 0;
        end else begin
            mont_start <= 0;  // default off unless pulsed

            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        exp_reg <= exponent;

                        for (int i = 0; i < S; i++) begin
                            R0[i] <= mont_one[i];
                            R1[i] <= base[i];
                        end

                        state <= INIT;
                    end
                end

                INIT: begin
                    if (exp_reg == 0) begin
                        for (int i = 0; i < S; i++)
                            result[i] <= mont_one[i];
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        current_bit <= exp_reg[0];
                        for (int i = 0; i < S; i++) begin
                            a[i] <= R0[i];
                            b[i] <= current_bit ? R1[i] : R0[i];
                        end
                        mont_start <= 1;
                        state <= MULT1_START;
                    end
                end

                MULT1_START: begin
                    // Wait for done in next state
                    state <= MULT1_WAIT;
                end

                MULT1_WAIT: begin
                    if (mont_done) begin
                        if (current_bit) begin
                            for (int i = 0; i < S; i++) R0[i] <= Tout[i];
                        end else begin
                            for (int i = 0; i < S; i++) R1[i] <= Tout[i];
                        end

                        for (int i = 0; i < S; i++) begin
                            a[i] <= current_bit ? R1[i] : R0[i];
                            b[i] <= R1[i];
                        end
                        mont_start <= 1;
                        state <= MULT2_START;
                    end
                end

                MULT2_START: begin
                    state <= MULT2_WAIT;
                end

                MULT2_WAIT: begin
                    if (mont_done) begin
                        if (current_bit) begin
                            for (int i = 0; i < S; i++) R1[i] <= Tout[i];
                        end else begin
                            for (int i = 0; i < S; i++) R0[i] <= Tout[i];
                        end

                        exp_reg <= exp_reg >> 1;

                        if (exp_reg == 1) begin
                            for (int i = 0; i < S; i++) result[i] <= Tout[i];
                            done <= 1;
                            state <= FINALIZE;
                        end else begin
                            state <= INIT;
                        end
                    end
                end

                FINALIZE: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

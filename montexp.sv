module montexp #(
    parameter int WIDTH    = 8,
    parameter int R_WIDTH  = 8,
    parameter int EWIDTH   = 8,
    parameter int S        = 2,   // number of limbs (words)
    parameter int N        = 2    // for montcios internal depth
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  start,
    input  logic [WIDTH-1:0]      base [S],
    input  logic [EWIDTH-1:0]     exponent,
    input  logic [WIDTH-1:0]      n [S],
    input  logic [R_WIDTH-1:0]    n_prime,
    input  logic [WIDTH-1:0]      mont_one [S],

    output logic [WIDTH-1:0]      result [S],
    output logic                  done
);

    typedef enum logic [3:0] {
        IDLE,
        INIT,
        SET_MULTIPLY, START_MULTIPLY, WAIT_MULTIPLY,
        SET_SQUARE,   START_SQUARE,   WAIT_SQUARE,
        DONE
    } state_t;

    state_t state;

    // Internal data registers
    logic [WIDTH-1:0] R0 [S];
    logic [WIDTH-1:0] R1 [S];
    logic [WIDTH-1:0] a  [S];
    logic [WIDTH-1:0] b  [S];
    logic [WIDTH-1:0] Tout [S];

    logic             mult_start, mult_done;

    montcios #(.WIDTH(WIDTH), .S(S), .N(N)) mult (
        .clk(clk),
        .rst(rst),
        .start(mult_start),
        .a(a),
        .b(b),
        .p(n),
        .p_prime(n_prime),
        .done(mult_done),
        .Tout(Tout)
    );

    logic [EWIDTH-1:0] exp_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            done        <= 0;
            mult_start  <= 0;
            for (int i = 0; i < S; i++) begin
                result[i] <= 0;
            end
        end else begin
            mult_start <= 0; // default: one-cycle pulse

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
                            result[i] <= R0[i];
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        for (int i = 0; i < S; i++) begin
                            a[i] <= R0[i];
                            b[i] <= R1[i];
                        end
                        state <= SET_MULTIPLY;
                    end
                end

                SET_MULTIPLY: begin
                    state <= START_MULTIPLY;
                end

                START_MULTIPLY: begin
                    mult_start <= 1;
                    state <= WAIT_MULTIPLY;
                end

                WAIT_MULTIPLY: begin
                    if (mult_done) begin
                        if (exp_reg[0]) begin
                            for (int i = 0; i < S; i++)
                                R0[i] <= Tout[i];
                        end else begin
                            for (int i = 0; i < S; i++)
                                R1[i] <= Tout[i];
                        end
                        state <= SET_SQUARE;
                    end
                end

                SET_SQUARE: begin
                    if (exp_reg[0]) begin
                        for (int i = 0; i < S; i++) begin
                            a[i] <= R1[i];
                            b[i] <= R1[i];
                        end
                    end else begin
                        for (int i = 0; i < S; i++) begin
                            a[i] <= R0[i];
                            b[i] <= R0[i];
                        end
                    end
                    state <= START_SQUARE;
                end

                START_SQUARE: begin
                    mult_start <= 1;
                    state <= WAIT_SQUARE;
                end

                WAIT_SQUARE: begin
                    if (mult_done) begin
                        if (exp_reg[0]) begin
                            for (int i = 0; i < S; i++)
                                R1[i] <= Tout[i];
                        end else begin
                            for (int i = 0; i < S; i++)
                                R0[i] <= Tout[i];
                        end

                        exp_reg <= exp_reg >> 1;
                        state <= INIT;
                    end
                end

                DONE: begin
                    done <= 1;
                    for (int i = 0; i < S; i++)
                        result[i] <= R0[i];
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

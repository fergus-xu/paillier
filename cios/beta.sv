module montgomery_pe #(
    parameter int width = 32
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic [width-1:0] SIn,
    input logic [width-1:0] p_prime,
    input logic [width-1:0] p0,

    output logic [width-1:0] COut,
    output logic [width-1:0] m,
    output logic done
);

    typedef enum logic [1:0] {
        IDLE,
        MUL1,
        MUL2,
        ADD,
        DONE
    } state_t;

    state_t state, next_state;

    logic [width-1:0] SIn_reg, p_prime_reg, p0_reg;
    logic [2*width-1:0] t1, t2, t3;

    // FSM state update
    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (en) next_state = MUL1;
            MUL1:  next_state = MUL2;
            MUL2:  next_state = ADD;
            ADD:   next_state = DONE;
            DONE:  next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            SIn_reg   <= '0;
            p_prime_reg <= '0;
            p0_reg    <= '0;
            t1        <= '0;
            t2        <= '0;
            t3        <= '0;
            COut      <= '0;
            m         <= '0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: if (en) begin
                    SIn_reg   <= SIn;
                    p_prime_reg <= p_prime;
                    p0_reg    <= p0;
                end

                MUL1: begin
                    t1 <= SIn_reg * p_prime_reg;
                    m  <= (SIn_reg * p_prime_reg)[width-1:0];
                end

                MUL2: begin
                    t2 <= p0_reg * m;
                end

                ADD: begin
                    t3   <= SIn_reg + t2;
                end

                DONE: begin
                    COut <= t3[2*width-1:width];
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

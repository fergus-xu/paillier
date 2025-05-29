module gamma_cell #(
    parameter int width = 32
)(
    input logic clk,
    input logic rst,
    input logic start,     // starts computation
    input logic [width-1:0] CIn,    // carry-in
    input logic [width-1:0] SIn,    // T[j]
    input logic [width-1:0] m,      // reduction digit
    input logic [width-1:0] p_j,    // p[j]

    output logic [width-1:0] SOut,   // updated T[j]
    output logic [width-1:0] COut,   // carry-out to T[j+1]
    output logic [width-1:0] m_out,  // forwarded unchanged
    output logic done    // valid for 1 cycle
);

    typedef enum logic [1:0] {
        IDLE,
        MULT,
        ADD,
        DONE
    } state_t;

    state_t state, next_state;

    // Registers
    logic [width-1:0] SIn_reg, CIn_reg, m_reg, p_j_reg;
    logic [2*width-1:0] t1, t2, t3;

    // FSM state transition
    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (en) next_state = MULT;
            MULT:            next_state = ADD;
            ADD:             next_state = DONE;
            DONE:            next_state = IDLE;
        endcase
    end

    // FSM operation
    always_ff @(posedge clk) begin
        if (rst) begin
            SIn_reg <= '0;
            CIn_reg <= '0;
            m_reg   <= '0;
            p_j_reg <= '0;
            t1      <= '0;
            t2      <= '0;
            t3      <= '0;
            SOut    <= '0;
            COut    <= '0;
            m_out   <= '0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: if (en) begin
                    SIn_reg <= SIn;
                    CIn_reg <= CIn;
                    m_reg   <= m;
                    p_j_reg <= p_j;
                end

                MULT: begin
                    t1 <= SIn_reg + CIn_reg;
                    t2 <= m_reg * p_j_reg;
                end

                ADD: begin
                    t3 <= t1 + t2;
                end

                DONE: begin
                    SOut  <= t3[width-1:0];                     // LSW
                    COut  <= t3[2*width-1:width];         // MSW
                    m_out <= m_reg;                                 // Pass-through
                    done  <= 1'b1;
                end
            endcase
        end
    end

endmodule

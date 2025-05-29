module normalize_pe #(
    parameter int WORD_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   en,        // start computation
    input  logic [WORD_WIDTH-1:0] CIn,       // carry in
    input  logic [WORD_WIDTH-1:0] S1In,      // T[s]
    input  logic [WORD_WIDTH-1:0] S2In,      // T[s+1]

    output logic [WORD_WIDTH-1:0] COut,      // T[s]
    output logic [WORD_WIDTH-1:0] SOut,      // T[s - 1]
    output logic                  done       // high for 1 cycle
);

    typedef enum logic [1:0] {
        IDLE,
        ADD1,
        ADD2,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    logic [WORD_WIDTH-1:0] CIn_reg, S1In_reg, S2In_reg;
    logic [WORD_WIDTH-1:0] t2;     // MSW(t1)
    logic [WORD_WIDTH:0]   t1;
    logic [WORD_WIDTH:0]   t4;

    // FSM state transition
    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (en) next_state = ADD1;
            ADD1:            next_state = ADD2;
            ADD2:            next_state = DONE;
            DONE:            next_state = IDLE;
        endcase
    end

    // FSM computation
    always_ff @(posedge clk) begin
        if (rst) begin
            CIn_reg  <= '0;
            S1In_reg <= '0;
            S2In_reg <= '0;
            t1       <= '0;
            t2       <= '0;
            t4       <= '0;
            SOut     <= '0;
            COut     <= '0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: if (en) begin
                    CIn_reg  <= CIn;
                    S1In_reg <= S1In;
                    S2In_reg <= S2In;
                end

                ADD1: begin
                    t1 <= S1In_reg + CIn_reg;           // t1 = S1In + CIn
                    t2 <= (S1In_reg + CIn_reg)[WORD_WIDTH]; // MSB = carry out
                    SOut <= (S1In_reg + CIn_reg)[WORD_WIDTH-1:0]; // LSW
                end

                ADD2: begin
                    t4 <= S2In_reg + t2;
                    COut <= (S2In_reg + t2)[WORD_WIDTH-1:0]; // LSW of second sum
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

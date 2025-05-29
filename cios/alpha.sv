module alpha #(
    parameter width = 32
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] Sin,
    input logic [width-1:0] Cin,

    output logic [width-1:0] Sout,
    output logic [width-1:0] Cout,
    output logic done
)
    typedef enum logic [1:0] {
        IDLE,
        MUL,
        ACC,
        DONE
    } state_t;

    state_t state, next_state;

    logic [WORD_WIDTH-1:0] a_reg, b_reg;
    logic [WORD_WIDTH-1:0] sin_reg, cin_reg;
    logic [2*WORD_WIDTH-1:0] mult_reg;
    logic [2*WORD_WIDTH-1:0] result_reg;

    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (en)    next_state = MUL;
            MUL:             next_state = ACC;
            ACC:             next_state = DONE;
            DONE:            next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            a_reg       <= '0;
            b_reg       <= '0;
            sin_reg     <= '0;
            cin_reg     <= '0;
            mult_reg    <= '0;
            result_reg  <= '0;
            SOut        <= '0;
            COut        <= '0;
            done        <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (en) begin
                        a_reg   <= a;
                        b_reg   <= b;
                        sin_reg <= SIn;
                        cin_reg <= CIn;
                    end
                end
                MUL: begin
                    mult_reg <= a_reg * b_reg;
                end
                ACC: begin
                    result_reg <= mult_reg + sin_reg + cin_reg;
                end
                DONE: begin
                    SOut <= result_reg[WORD_WIDTH-1:0];
                    COut <= result_reg[2*WORD_WIDTH-1:WORD_WIDTH];
                    done <= 1'b1;
                end
                default;
            endcase
        end

endmodule
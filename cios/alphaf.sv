module alphaf #(
    parameter int width = 32
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic [width-1:0] CIn,
    input logic [width-1:0] SIn,

    output logic [width-1:0] SOut,
    output logic [width-1:0] COut,
    output logic done
);

    typedef enum logic [1:0] {
        IDLE,
        ADD,
        DONE
    } state_t;

    state_t state, next_state;

    logic [width:0] t1;

    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (en) next_state = ADD;
            ADD:         next_state = DONE;
            DONE:        next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            t1   <= '0;
            SOut <= '0;
            COut <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                ADD: begin
                    t1 <= SIn + CIn;
                end
                DONE: begin
                    SOut <= t1[width-1:0];
                    COut <= { {width-1{1'b0}}, t1[width] };
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

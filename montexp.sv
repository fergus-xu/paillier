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

    output logic [WIDTH-1:0] result,
    output logic done
)

    typedef enum logic [2:0] {
        IDLE, INIT, SQUARE, MULTIPLY, UPDATE, FINISH
    };

    montmult(.clk(clk), .rst(rst), .start(mult_start), .)

endmodule
module alpha_f #(
    parameter int WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  en,

    input  logic [WIDTH-1:0]      Cin,
    input  logic [WIDTH-1:0]      Sin,

    output logic [WIDTH-1:0]      Cout,
    output logic [WIDTH-1:0]      Sout
);

    logic [2*WIDTH-1:0] t1;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            t1 <= '0;
        else if (en)
            t1 <= Cin + Sin;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            Sout <= '0;
            Cout <= '0;
        end else begin
            Sout <= t1[WIDTH-1:0];
            Cout <= t1[2*WIDTH-1:WIDTH];
        end
    end

endmodule

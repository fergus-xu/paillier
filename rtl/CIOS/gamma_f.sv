module gamma_f #(
  parameter int WIDTH = 32
)(
  input  logic             clk,
  input  logic             rst,
  input  logic             en,

  input  logic [WIDTH-1:0] Cin,     // C
  input  logic [WIDTH-1:0] S1in,    // T[s]
  input  logic [WIDTH-1:0] S2in,    // T[s+1]

  output logic [WIDTH-1:0] Cout,    // T[s]
  output logic [WIDTH-1:0] Sout     // T[s−1]
);

  logic [2*WIDTH-1:0] t1;
  logic [WIDTH-1:0]   S2in_reg;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      t1        <= 0;
      S2in_reg  <= 0;
    end else if (en) begin
      t1        <= S1in + Cin;
      S2in_reg  <= S2in;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      Cout <= 0;
      Sout <= 0;
    end else if (en) begin
      Sout <= t1[WIDTH-1:0];
      Cout <= S2in_reg + t1[2*WIDTH-1:WIDTH];
    end
  end

endmodule

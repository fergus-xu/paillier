module gamma #(
  parameter int WIDTH = 32
)(
  input  logic             clk,
  input  logic             rst,
  input  logic             en,

  input  logic [WIDTH-1:0] Cin,     // C
  input  logic [WIDTH-1:0] Sin,     // T[j]
  input  logic [WIDTH-1:0] m,       // from beta
  input  logic [WIDTH-1:0] pj,      // p[j]

  output logic [WIDTH-1:0] Cout,    // MSW(t3)
  output logic [WIDTH-1:0] Sout     // LSW(t3)
);

  logic [WIDTH-1:0]  t1;
  logic [2*WIDTH-1:0] t2;
  logic [2*WIDTH-1:0] t3;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      t1 <= 0;
      t2 <= 0;
    end else if (en) begin
      t1 <= Sin + Cin;
      t2 <= m * pj;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      t3 <= 0;
    end else if (en) begin
      t3 <= t1 + t2;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      Cout <= 0;
      Sout <= 0;
    end else if (en) begin
      Cout <= t3[2*WIDTH-1:WIDTH];   // MSW
      Sout <= t3[WIDTH-1:0];         // LSW
    end
  end

endmodule

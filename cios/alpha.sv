module systolic_pe #(
  parameter WIDTH = 16  // word width
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   en,
  input  logic [WIDTH-1:0]       a,
  input  logic [WIDTH-1:0]       b,
  input  logic [WIDTH-1:0]       CIn,
  input  logic [WIDTH-1:0]       SIn,
  output logic [WIDTH-1:0]       COut,
  output logic [WIDTH-1:0]       SOut
);

  logic [WIDTH:0]       t1;
  logic [2*WIDTH-1:0]   t2;
  logic [2*WIDTH:0]     t3;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      COut <= 0;
      SOut <= 0;
    end else if (en) begin
      t1   = SIn + CIn;
      t2   = a * b;
      t3   = t2 + t1;

      SOut <= t3[WIDTH-1:0];
      COut <= t3[2*WIDTH-1:WIDTH]; 
    end
  end

endmodule

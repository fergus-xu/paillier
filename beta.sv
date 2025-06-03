module beta #(
  parameter int WIDTH = 32
)(
  input  logic             clk,
  input  logic             rst,
  input  logic             en,

  input  logic [WIDTH-1:0] Sin,    // T[0]
  input  logic [WIDTH-1:0] p0,     // p[0]
  input  logic [WIDTH-1:0] p_prime,   // p'

  output logic [WIDTH-1:0] Cout,   // MSW(t3)
  output logic [WIDTH-1:0] m       // LSW(t1)
);

  // === Stage 1 ===
  logic [2*WIDTH-1:0] t1;
  logic [WIDTH-1:0]   m_reg;
  logic [WIDTH-1:0]   sin_reg;

  // === Stage 2 ===
  logic [2*WIDTH-1:0] t2;
  logic [WIDTH-1:0]   sin_pipe;
  logic [WIDTH-1:0] m_pipe;

  // === Stage 3 ===
  logic [2*WIDTH-1:0] t3;

  // === Stage 1 ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            t1      <= 0;
            m_reg   <= 0;
            sin_reg <= 0;
        end else if (en) begin
            t1      <= Sin * p_prime;
            m_reg   <= {(Sin * p_prime)}[WIDTH-1:0];
            sin_reg <= Sin;
        end
    end

    // === Stage 2 ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            t2       <= 0;
            sin_pipe <= 0;
        end else begin
            t2       <= p0 * m_reg;
            sin_pipe <= sin_reg;
            m_pipe<= m_reg;
        end
    end

    // === Stage 3 ===
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            t3   <= 0;
            Cout <= 0;
            m    <= 0;
        end else begin
            t3   <= sin_pipe + t2;
            Cout <= {(sin_pipe + t2)}[2*WIDTH-1:WIDTH];  // MSW(t3)
            m    <= m_pipe;
        end
    end

endmodule

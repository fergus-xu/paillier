module alpha #(
  parameter WIDTH = 16  // word width
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   en,

    input  logic [WIDTH-1:0]       a,
    input  logic [WIDTH-1:0]       b,
    input  logic [WIDTH-1:0]       Cin,
    input  logic [WIDTH-1:0]       Sin,

    output logic [WIDTH-1:0]       Cout,
    output logic [WIDTH-1:0]       Sout
);

	logic [WIDTH:0]       t1;
	logic [2*WIDTH-1:0]   t2;
	logic [2*WIDTH-1:0]     t3;
  

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			t1 <= 0;
            t2 <= 0;
		end else if (en) begin
			t1 <= Sin + Cin;
            t2 <= a * b;
		end
	end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            t3 <= 0;
        end else begin
            t3 <= t1 + t2;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            Sout <= 0;
            Cout <= 0;
        end else begin
            Sout <= t3[WIDTH-1:0];
            Cout <= t3[2*WIDTH-1:WIDTH];
        end
    end

endmodule

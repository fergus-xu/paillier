module montcios #(
    parameter int width = 32,
    parameter int S = 8, // number of limbs
    paramter int n = 3 // number of cells
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [width-1:0] a [S],
    input  logic [width-1:0] b [S],
    input  logic [width-1:0] p [S],
    input  logic [width-1:0] p_inv,

    output logic [width-1:0] T_out [S+1],
    output logic done
);


    logic [width-1:0] T [S+2];
    logic [width-1:0] a_bus;
    logic [width-1:0] b_bus;

    always_ff @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            T_out <= '0;
            T <= '0;
        end
    end
    
    logic [$clog2(S):0] idx; 
    logic [width-1:0] Cin, Sin;

    logic [width-1:0] bin;
    logic done;

    assign bin = b[idx];
    assign done = (idx == N);
    assign Sin = T[j];

    always_ff(@posedge clk) begin
        if (rst) begin
            idx <= 0;
            Sin <= 0;
            Cin <= 0;
        end else if (en && (idx < N)) begin
            if (idx == 0) 
                Cin <= 0;
            else 
                Cin <= Cout;
            T[j] <= Sout;
            idx <= idx + 1;

            if (idx == N-1) 
                en <= 0;
        end
    end
    
    alpha #(.WIDTH(width)) a1 (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(a),
        .b(bin),
        .Cin(Cin),
        .Sin(Sin),
        .Cout(Cout),
        .Sout(Sout)
    )

endmodule

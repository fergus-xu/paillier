module montcios #(
    parameter int WIDTH = 32,
    parameter int S     = 8,
    parameter int N     = 3
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  mont_start,
    input  logic [WIDTH-1:0]     a [S],
    input  logic [WIDTH-1:0]     b [S],
    input  logic [WIDTH-1:0]     p [S],
    input  logic [WIDTH-1:0]     p_prime,
    output logic                 done,
    output logic [WIDTH-1:0]     Tout [S]
);

    // Shared T bus
    logic [WIDTH-1:0] T [S+2];
    genvar i;
    generate
        for (i = 0; i < S; i++) begin : copy_T_to_Tout
            assign Tout[i] = T[i];
        end
    endgenerate

    // Row control signals
    logic start         [N];
    logic internal_done [N];
    logic active        [N];
    logic flush         [N];

    // Data assignments per row
    logic [WIDTH-1:0] a_selected     [N];
    logic [WIDTH-1:0] b_selected     [N][S];
    logic [WIDTH-1:0] p_selected     [N][S];
    logic [WIDTH-1:0] pinv_selected  [N];

    logic [$clog2(S+1):0] a_index;
    logic [$clog2(N)-1:0] next_unit;
    logic [$clog2(S+1):0] completed;

    // Launch delay control
    localparam int LAUNCH_DELAY = 17;
    logic [$clog2(LAUNCH_DELAY+1):0] launch_timer;

    // Write buses
    logic we    [N];
    logic [$clog2(S+2)-1:0] waddr [N];
    logic [WIDTH-1:0]       wdata [N];

    // Flush handling
    logic prev_done [N];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                flush[i]     <= 0;
                prev_done[i] <= 0;
            end
        end else begin
            for (int i = 0; i < N; i++) begin
                flush[i]     <= internal_done[i] && !prev_done[i];  // one-cycle pulse on rising edge
                prev_done[i] <= internal_done[i];
            end
        end
    end

    // Main control logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_index      <= 0;
            next_unit    <= 0;
            completed    <= 0;
            launch_timer <= 0;

            for (int i = 0; i < N; i++) begin
                start[i]  <= 0;
                active[i] <= 0;
            end

            for (int i = 0; i < S+2; i++)
                T[i] <= '0;

        end else begin
            // Clear start signals
            for (int i = 0; i < N; i++)
                start[i] <= 0;

            // Check for completed units
            for (int i = 0; i < N; i++) begin
                if (active[i] && internal_done[i]) begin
                    active[i] <= 0;
                    completed <= completed + 1;
                end
            end

            // Handle launch timer
            if (launch_timer > 0) begin
                launch_timer <= launch_timer - 1;
            end else if (a_index < S) begin
                automatic bit found = 0;
                for (int offset = 0; offset < N; offset++) begin
                    automatic int idx = (next_unit + offset) % N;
                    if (!active[idx] && !found) begin
                        a_selected[idx] <= a[a_index];
                        for (int j = 0; j < S; j++) begin
                            b_selected[idx][j] <= b[j];
                            p_selected[idx][j] <= p[j];
                        end
                        pinv_selected[idx] <= p_prime;

                        start[idx]        <= 1;
                        active[idx]       <= 1;
                        a_index           <= a_index + 1;
                        launch_timer      <= LAUNCH_DELAY - 1;
                        next_unit         <= (idx + 1) % N;

                        found = 1;
                    end
                end
            end
        end
    end

    assign done = (completed == S);

    // Shared T writeback
    always_ff @(posedge clk) begin
        for (int i = 0; i < N; i++) begin
            if (we[i]) begin
                T[waddr[i]] <= wdata[i];
            end
        end
    end

    // Instantiate parallel CIOS rows
    for (genvar i = 0; i < N; i++) begin : row
        ciosrow #(.WIDTH(WIDTH), .S(S)) u_ciosrow (
            .clk(clk),
            .rst(rst),
            .flush(flush[i]),
            .start(start[i]),
            .a(a_selected[i]),
            .b(b_selected[i]),
            .p(p_selected[i]),
            .p_prime(pinv_selected[i]),
            .T(T),
            .we(we[i]),
            .waddr(waddr[i]),
            .wdata(wdata[i]),
            .done(internal_done[i])
        );
    end

endmodule

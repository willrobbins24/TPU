`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2026 05:39:44 PM
// Design Name: 
// Module Name: deskew_TB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module deskew_TB;

    localparam int N            = 4;
    localparam int FACTOR_WIDTH = 32;
    localparam int ADDR_WIDTH   = 3;

    logic clk = 0;
    logic rst_n;

    logic                    start;
    logic [ADDR_WIDTH-1:0]   addr_in;
    logic                    accumulate_in;
    logic signed [FACTOR_WIDTH-1:0] array_edge [N];

    logic                    wr_en;
    logic [ADDR_WIDTH-1:0]   wr_addr;
    logic                    wr_accumulate;
    logic signed [FACTOR_WIDTH-1:0] wr_data [N];

    int errors = 0;
    longint cycle_count;

    deskew #(
        .N(N), .FACTOR_WIDTH(FACTOR_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .addr_in(addr_in), .accumulate_in(accumulate_in),
        .array_edge(array_edge),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_accumulate(wr_accumulate), .wr_data(wr_data)
    );

    always #5 clk = ~clk;
    initial begin 
    start = 0;
    array_edge[0] = 0;
    array_edge[1] = 0;
    array_edge[2] = 0;
    array_edge[3] = 0;
    @(posedge clk);
    start = 1;
    array_edge[0] = 1;
    @(posedge clk);
    start = 0;
    array_edge[0] = 0;
    array_edge[1] = 2;
    @(posedge clk);
    array_edge[1] = 0;
    array_edge[2] = 3;
    @(posedge clk);
    array_edge[2] = 0;
    array_edge[3] = 4;
    @(posedge clk);
    array_edge[3] = 0;
    @(posedge clk);
$finish;
end
//    always_ff @(posedge clk or negedge rst_n) begin
//        if (!rst_n) cycle_count <= 0;
//        else        cycle_count <= cycle_count + 1;
//    end

//    // Free-running bus: each lane's value changes every cycle, keyed
//    // off the current cycle number, so a wrong capture cycle produces
//    // a visibly wrong value instead of silently matching stale data.
//    always_comb begin
//        for (int i = 0; i < N; i++)
//            array_edge[i] = cycle_count * 100 + i;
//    end

//    // ---- scoreboard: FIFO of expected groups ----
//    typedef struct {
//        int addr;
//        bit accum;
//        logic [FACTOR_WIDTH-1:0] data [N];
//    } expected_t;

//    expected_t scoreboard[$];
//    expected_t curr_expected;

//    task automatic issue_group(input int addr, input bit accum);
//        expected_t e;
//        @(negedge clk);
//        e.addr  = addr;
//        e.accum = accum;
//        for (int i = 0; i < N; i++)
//            e.data[i] = (cycle_count + i) * 100 + i;
//        scoreboard.push_back(e);

//        start         = 1;
//        addr_in       = addr;
//        accumulate_in = accum;
//        @(negedge clk);
//        start = 0;
//    endtask

//    always_ff @(posedge clk) begin
//        if (rst_n && wr_en) begin
//            if (scoreboard.size() == 0) begin
//                $display("ERROR: unexpected wr_en with empty scoreboard");
//                errors++;
//            end else begin
//                curr_expected = scoreboard.pop_front();
//                if (wr_addr !== curr_expected.addr) begin
//                    $display("ERROR: wr_addr got %0d expected %0d", wr_addr, curr_expected.addr);
//                    errors++;
//                end
//                if (wr_accumulate !== curr_expected.accum) begin
//                    $display("ERROR: wr_accumulate got %0d expected %0d", wr_accumulate, curr_expected.accum);
//                    errors++;
//                end
//                for (int i = 0; i < N; i++) begin
//                    if (wr_data[i] !== curr_expected.data[i]) begin
//                        $display("ERROR: lane %0d got %0d expected %0d", i, wr_data[i], curr_expected.data[i]);
//                        errors++;
//                    end
//                end
//            end
//        end
//    end

//    initial begin
//        rst_n = 0; start = 0; addr_in = 0; accumulate_in = 0;
//        repeat (2) @(posedge clk);
//        rst_n = 1;
//        repeat (2) @(posedge clk);

//        // Back-to-back groups on consecutive cycles -- exercises the
//        // fact that the triangular delay network is a true pipeline
//        // with no stalling between groups, unlike the earlier
//        // FSM-based capture-then-flush design.
//        issue_group(1, 1'b0);
//        issue_group(2, 1'b1);
//        issue_group(3, 1'b0);

//        // wait long enough for all groups to drain (N-1 cycle latency
//        // plus a margin)
//        repeat (N + 4) @(posedge clk);

//        if (scoreboard.size() != 0) begin
//            $display("ERROR: %0d expected group(s) never arrived", scoreboard.size());
//            errors++;
//        end

//        if (errors == 0)
//            $display("\n*** ALL TESTS PASSED ***\n");
//        else
//            $display("\n*** %0d ERROR(S) ***\n", errors);

//        $finish;
//    end

endmodule


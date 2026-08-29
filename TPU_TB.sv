`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/28/2026 03:16:04 PM
// Design Name: 
// Module Name: TPU_TB
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
// tb_TPU.sv
//
// Small, self-checking testbench for the TPU top module (N = 4).
//
// Sequence:
//   1. Reset.
//   2. Stream weight tile 1 (16 elements) -> should load as:
//         13 14 15 16
//          9 10 11 12
//          5  6  7  8
//          1  2  3  4
//      Wait for the first double-buffer swap (bank now active).
//   3. Pulse activation vector [1,2,3,4] into address 0 (overwrite).
//      Wait for the internal write to address 0, then read it back and
//      check it equals [50,60,70,80].
//   4. Stream weight tile 2 (16 elements) -> should load as the identity
//      matrix. Wait for the second double-buffer swap.
//   5. Pulse activation vector [5,6,7,8] into address 1 (overwrite).
//      Wait for the internal write to address 1, then read it back and
//      check it equals [5,6,7,8].
//   6. Report PASS/FAIL and finish.
//
// Notes:
//   - psum_in_edge is tied to 0, per the "controller ties it to 0 for the
//     single-pass case" decision.
//   - dut.wr_en / dut.wr_addr / dut.buf_swapped are internal TPU wires,
//     referenced hierarchically so the testbench can wait on real
//     handshakes instead of hardcoded cycle counts.
//   - Weight tile 2 is streamed *after* checking vector 1's result rather
//     than overlapped with it, purely to keep this "small" testbench easy
//     to follow. The design supports overlapping them (that's the point
//     of double buffering).
//////////////////////////////////////////////////////////////////////////////////
 
module TPU_TB;
 
    // ---------------------------------------------------------------
    // Parameters (match TPU's defaults)
    // ---------------------------------------------------------------
    localparam int N            = 4;
    localparam int FACTOR_WIDTH = 8;
    localparam int PSUM_WIDTH   = 32;
    localparam int ADDR_WIDTH   = 3;
 
    // ---------------------------------------------------------------
    // DUT connections
    // ---------------------------------------------------------------
    logic                             clk;
    logic                             rst_n;
 
    logic                             valid_in;
    logic signed [FACTOR_WIDTH-1:0]   vector_in [N];
    logic        [ADDR_WIDTH-1:0]     wr_addr_in;
    logic                             wr_accumulate_in;
 
    logic                             rd_en;
    logic        [ADDR_WIDTH-1:0]     rd_addr;
    logic        [PSUM_WIDTH-1:0]     rd_data [N];
    logic                             rd_valid;
 
    logic                             wr_valid_in;
    logic signed [FACTOR_WIDTH-1:0]   wr_data_in;
    logic                             wr_ready;
 
    logic signed [PSUM_WIDTH-1:0]     psum_in_edge [N-1:0];
 
    // ---------------------------------------------------------------
    // Clock generation (100 MHz)
    // ---------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // ---------------------------------------------------------------
    // DUT instantiation
    // ---------------------------------------------------------------
    TPU dut (
        .clk               (clk),
        .rst_n             (rst_n),
 
        .valid_in          (valid_in),
        .vector_in         (vector_in),
        .wr_addr_in        (wr_addr_in),
        .wr_accumulate_in  (wr_accumulate_in),
 
        .rd_en             (rd_en),
        .rd_addr           (rd_addr),
        .rd_data           (rd_data),
        .rd_valid          (rd_valid),
 
        .wr_valid_in       (wr_valid_in),
        .wr_data_in        (wr_data_in),
        .wr_ready          (wr_ready),
 
        .psum_in_edge      (psum_in_edge)
    );
 
    // ---------------------------------------------------------------
    // Stimulus data
    // ---------------------------------------------------------------
    // Full 32-element stream: tile 1 (rows 1..4), then tile 2 (identity).
    byte tile1 [0:15] = '{1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
    byte tile2 [0:15] = '{0,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0};
 
    // Expected accumulator results.
    logic [PSUM_WIDTH-1:0] expected_addr0 [N] = '{50, 60, 70, 80};
    logic [PSUM_WIDTH-1:0] expected_addr1 [N] = '{5, 6, 7, 8};
 
    int errors = 0;
 
    // ---------------------------------------------------------------
    // Watchdog: fail loudly instead of hanging forever
    // ---------------------------------------------------------------
    initial begin
        #100000; // 100us
        $display("[%0t] TIMEOUT: testbench did not complete in time.", $time);
        $display("RESULT: FAIL");
        $finish;
    end
 
    // ---------------------------------------------------------------
    // Task: stream one 16-element weight tile through wr_valid_in/wr_data_in,
    // respecting the wr_ready handshake.
    // ---------------------------------------------------------------
    task automatic stream_tile(input byte data [0:15]);
        int idx;
        idx = 0;
        @(posedge clk);
        wr_valid_in <= 1'b1;
        wr_data_in  <= data[0];
        forever begin
            @(posedge clk);
            // Reading wr_valid_in/wr_ready here (no delay) sees the
            // pre-edge values, matching what weight_loader's own
            // always_ff sampled at this same edge.
            if (wr_valid_in && wr_ready) begin
                idx++;
                if (idx < 16) begin
                    wr_data_in <= data[idx];
                end else begin
                    wr_valid_in <= 1'b0;
                    break;
                end
            end
        end
    endtask
 
    // ---------------------------------------------------------------
    // Task: wait for the next double-buffer swap pulse.
    // ---------------------------------------------------------------
    task automatic wait_for_swap();
        forever begin
            @(posedge clk);
            #1; // let this edge's NBA updates settle before reading
            if (dut.buf_swapped) break;
        end
    endtask
 
    // ---------------------------------------------------------------
    // Task: pulse one activation vector into the array for one cycle.
    // ---------------------------------------------------------------
    task automatic pulse_vector(input logic signed [FACTOR_WIDTH-1:0] vec [N],
                                 input logic [ADDR_WIDTH-1:0] addr,
                                 input logic accumulate);
        @(posedge clk);
        valid_in         <= 1'b1;
        vector_in         = vec;
        wr_addr_in       <= addr;
        wr_accumulate_in <= accumulate;
        @(posedge clk);
        valid_in         <= 1'b0;
    endtask
 
    // ---------------------------------------------------------------
    // Task: wait for the internal accumulator write to a specific address.
    // ---------------------------------------------------------------
    task automatic wait_for_write(input logic [ADDR_WIDTH-1:0] addr);
        forever begin
            @(posedge clk);
            #1; // let this edge's NBA updates settle before reading
            if (dut.wr_en && dut.wr_addr == addr) break;
        end
    endtask
 
    // ---------------------------------------------------------------
    // Task: read back one accumulator address and check it.
    // ---------------------------------------------------------------
    task automatic read_and_check(input logic [ADDR_WIDTH-1:0] addr,
                                   input logic [PSUM_WIDTH-1:0] expected [N],
                                   input string label);
        @(posedge clk);
        rd_en   <= 1'b1;
        rd_addr <= addr;
        @(posedge clk);
        rd_en   <= 1'b0;
        // rd_valid/rd_data are registered one cycle after rd_en; wait one
        // more edge and let this edge's NBA settle before reading.
        @(posedge clk);
        #1;
        if (!rd_valid) begin
            $display("[%0t] %s: FAIL - rd_valid not asserted", $time, label);
            errors++;
        end else begin
            for (int i = 0; i < N; i++) begin
                if (rd_data[i] !== expected[i]) begin
                    $display("[%0t] %s: FAIL - lane %0d = %0d, expected %0d",
                              $time, label, i, rd_data[i], expected[i]);
                    errors++;
                end
            end
            $display("[%0t] %s: rd_data = [%0d, %0d, %0d, %0d]",
                      $time, label, rd_data[0], rd_data[1], rd_data[2], rd_data[3]);
        end
    endtask
 
    // ---------------------------------------------------------------
    // Main sequence
    // ---------------------------------------------------------------
    initial begin
        // Idle defaults
        rst_n             = 1'b0;
        valid_in          = 1'b0;
        vector_in         = '{default: 0};
        wr_addr_in        = '0;
        wr_accumulate_in  = 1'b0;
        rd_en             = 1'b0;
        rd_addr           = '0;
        wr_valid_in       = 1'b0;
        wr_data_in        = '0;
        psum_in_edge      = '{default: 0}; // controller ties this to 0
 
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
 
        // ---- Step 1: stream weight tile 1 ----
        $display("[%0t] Streaming weight tile 1...", $time);
        stream_tile(tile1);
 
        // ---- Step 2: wait for the first bank swap ----
        $display("[%0t] Waiting for first buffer swap...", $time);
        wait_for_swap();
        $display("[%0t] First swap seen (active_sel_dbg = %0b).", $time, dut.active_sel_dbg);
 
        // ---- Step 3: pulse vector [1,2,3,4] into address 0 (overwrite) ----
        $display("[%0t] Pulsing vector [1,2,3,4] into address 0...", $time);
        pulse_vector('{1,2,3,4}, 3'd0, 1'b0);
 
        // ---- Step 4: wait for the write, then read address 0 back ----
        wait_for_write(3'd0);
        read_and_check(3'd0, expected_addr0, "addr0 (vector1 x tile1)");
 
        // ---- Step 5: stream weight tile 2 (identity) ----
        $display("[%0t] Streaming weight tile 2 (identity)...", $time);
        stream_tile(tile2);
 
        // ---- Step 6: wait for the second bank swap ----
        $display("[%0t] Waiting for second buffer swap...", $time);
        wait_for_swap();
        $display("[%0t] Second swap seen (active_sel_dbg = %0b).", $time, dut.active_sel_dbg);
 
        // ---- Step 7: pulse vector [5,6,7,8] into address 1 (overwrite) ----
        $display("[%0t] Pulsing vector [5,6,7,8] into address 1...", $time);
        pulse_vector('{5,6,7,8}, 3'd1, 1'b0);
 
        // ---- Step 8: wait for the write, then read address 1 back ----
        wait_for_write(3'd1);
        read_and_check(3'd1, expected_addr1, "addr1 (vector2 x tile2)");
 
        // ---- Report ----
        if (errors == 0) begin
            $display("RESULT: PASS");
        end else begin
            $display("RESULT: FAIL (%0d error(s))", errors);
        end
        $finish;
    end
 
endmodule
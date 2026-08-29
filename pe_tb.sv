`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/21/2026 08:04:19 PM
// Design Name: 
// Module Name: pe_tb
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


module pe_tb;
    // Testbench signals
    logic              clk;
    logic              rst_n;
    logic signed [7:0]  w_in;
    logic               w_ld_en;
    logic signed [7:0]  act_in;
    logic signed [31:0] psum_in;
    logic signed [7:0]  act_out;
    logic signed [31:0] psum_out;
    logic signed [7:0]  w_out;

    // Instantiate DUT
    pe dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .w_in     (w_in),
        .w_ld_en  (w_ld_en),
        .act_in   (act_in),
        .psum_in  (psum_in),
        .act_out  (act_out),
        .psum_out (psum_out),
        .w_out    (w_out)
    );

    // Clock generation: 10ns period (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        // 1. Reset
        rst_n   = 0;
        w_in    = 0;
        w_ld_en = 0;
        act_in  = 0;
        psum_in = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // 2. Load weight = 3
        w_ld_en = 1;
        w_in    = 8'sd3;
        @(negedge clk);
        w_ld_en = 0;

        // 3. Send activation = 5, psum_in = 0
        // Expect: psum_out = 0 + (3*5) = 15
        act_in  = 8'sd5;
        psum_in = 32'sd0;
        @(negedge clk);

        // Check result after this clock edge propagates
        #1; // small delay to let non-blocking assignments settle
        if (psum_out !== 32'sd15)
            $display("FAIL: expected psum_out=15, got %0d", psum_out);
        else
            $display("PASS: psum_out=15 as expected");

        // 4. Test negative activation: act_in = -4
        // Expect: psum_out = 15 (prev psum_in) + (3 * -4) = 15 - 12 = 3
        act_in  = -8'sd4;
        psum_in = 32'sd15;
        @(negedge clk);
        #1;
        if (psum_out !== 32'sd3)
            $display("FAIL: expected psum_out=3, got %0d", psum_out);
        else
            $display("PASS: psum_out=3 as expected");

        // 5. Check act_out and w_out pass-through
        if (act_out !== -8'sd4)
            $display("FAIL: act_out mismatch, got %0d", act_out);
        else
            $display("PASS: act_out passthrough correct");
        #5;
        @(posedge clk);
        rst_n = 0;
        #10;
        $display("Testbench complete.");
        $finish;
    end

endmodule


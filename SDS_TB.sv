`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2026 01:39:03 PM
// Design Name: 
// Module Name: SDS_TB
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


module SDS_TB;

    localparam int N            = 4;
    localparam int FACTOR_WIDTH = 8;
 
    logic clk = 0;
    logic rst_n;
    logic valid_in;
    logic signed [FACTOR_WIDTH-1:0] vector_in [N];
    logic signed [FACTOR_WIDTH-1:0] act_edge  [N-1:0];
    logic                           act_edge_valid [N];
 
    systolic_data_setup #(
        .N(N),
        .FACTOR_WIDTH(FACTOR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .vector_in(vector_in),
        .act_edge(act_edge),
        .act_edge_valid(act_edge_valid)
    );
 
    // 100MHz clock
    always #5 clk = ~clk;
 
    // Drive inputs on the negedge, same convention as the earlier RTL discussion
    task automatic drive(input logic v, input int a0, input int a1, input int a2, input int a3);
        @(negedge clk);
        valid_in     <= v;
        vector_in[0] <= a0;
        vector_in[1] <= a1;
        vector_in[2] <= a2;
        vector_in[3] <= a3;
    endtask
 
    initial begin
        rst_n = 0;
        valid_in = 0;
        vector_in = '{0,0,0,0};
        repeat (2) @(negedge clk);
        rst_n = 1;
 
        // Vector 1 = {1,2,3,4}, Vector 2 = {0,1,2,3} back-to-back
        drive(1, 1, 2, 3, 4);
        drive(1, 0, 1, 2, 3);
        drive(0, 0, 0, 0, 0);
 
        // Let the pipeline fully drain (up to N-1 = 3 extra cycles)
        repeat (6) @(negedge clk);
 
        $display("Simulation done.");
        $finish;
    end
 
    // Print the staggered outputs each cycle so you can see the diagonal
    // wavefront pattern (row 0 immediate, row 3 delayed by 3 cycles).
    always @(posedge clk) begin
        if (rst_n)
            $display("t=%0t | act_edge=%p valid=%p", $time, act_edge, act_edge_valid);
    end

endmodule

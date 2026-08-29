`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/23/2026 12:02:57 AM
// Design Name: 
// Module Name: SA_TB
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


module SA_TB#(
    parameter int N = 4,
    parameter int FACTOR_WIDTH = 8,
    parameter int PSUM_WIDTH = 32,
    parameter int ADDR_WIDTH   = 3
);

logic clk;
logic rst_n;

logic w_ld_en;
logic signed [FACTOR_WIDTH-1:0] w_in_edge [N-1:0];
logic signed [FACTOR_WIDTH-1:0] w_out_edge [N-1:0];

logic signed [FACTOR_WIDTH-1:0] act_in_edge [N-1:0];
logic signed [FACTOR_WIDTH-1:0] act_out_edge [N-1:0];

logic signed [PSUM_WIDTH-1:0] psum_in_edge  [N-1:0];
logic signed [PSUM_WIDTH-1:0] psum_out_edge  [N-1:0];

logic signed [FACTOR_WIDTH-1:0] golden_array [N-1:0][N-1:0];

//Input systolic vectors
    logic valid_in;
    logic signed [FACTOR_WIDTH-1:0] vector_in [N];
    logic signed [FACTOR_WIDTH-1:0] syst_act_edge  [N-1:0];
    logic                           act_edge_valid [N];
    
// deskew
    logic                    start;
    logic [ADDR_WIDTH-1:0]   addr_in;
    logic                    accumulate_in;
    logic signed [PSUM_WIDTH-1:0] array_edge [N];

    logic                    wr_en;
    logic [ADDR_WIDTH-1:0]   wr_addr;
    logic                    wr_accumulate;
    logic signed [PSUM_WIDTH-1:0] wr_data [N];

    int errors = 0;
    longint cycle_count;

    deskew #(
        .N(N), .FACTOR_WIDTH(FACTOR_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) desksew (
        .clk(clk), .rst_n(rst_n),
        .start(start), .addr_in(addr_in), .accumulate_in(accumulate_in),
        .array_edge(psum_out_edge),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_accumulate(wr_accumulate), .wr_data(wr_data)
    );

//instantiate syst_data

systolic_data_setup #(
        .N(N),
        .FACTOR_WIDTH(FACTOR_WIDTH)
    ) syst_data (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .vector_in(vector_in),
        .act_edge(syst_act_edge),
        .act_edge_valid(act_edge_valid)
    );
    
//instantiate dut
systolic_array dut (
    .clk(clk),
    .rst_n(rst_n),
    .w_ld_en(w_ld_en),
    .w_in_edge(w_in_edge),
    .w_out_edge(w_out_edge),
    .act_in_edge(syst_act_edge),
    .act_out_edge(act_out_edge),
    .psum_in_edge(psum_in_edge),
    .psum_out_edge(psum_out_edge)
);

// Clock generation: 10ns period (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;
    
    //generate weights
    task automatic gen_golden_weights();
        for (int r = 0; r < N; r++)
            for(int c = 0; c < N; c++)
                golden_array[c][N-1-r] = 1 + c + r*4;
    endtask
    
    //load weights (staggered)
    task automatic load_weights();
        @(negedge clk);
        w_ld_en = 1;
            for (int t = 0; t < N; t++) begin
                for (int c = 0; c < N; c++)
                    w_in_edge[c] = golden_array[c][N-1-t];
                @(negedge clk);
            end
        w_ld_en = 0;
    endtask
    
    //check weights
    task automatic check_weights();
    int errors = 0;
        logic signed [FACTOR_WIDTH -1:0] result;
        for (int r = N-1; r >= 0; r--) begin
            for (int c = 0; c < N; c++) begin
                result = dut.weight_dbg[c][r];
                if(result != golden_array[c][r]) begin
                    errors++;
                    $error("Weight mismatch at (row = %0d, col = %0d): result = %0d, expected = %0d", 
                    r, c, result, golden_array[c][r]);
                end
            end
        end
        if (errors == 0) begin
            $display("PASS: All weights loaded correctly");
        end
        else begin
            $display("FAIL: Weights loaded incorrectly");
        end
    endtask
    
    logic din;
    
    control_delay #(.WIDTH(1'b1), .DEPTH(N + 1)
        ) start_delay (
        .clk(clk), .rst_n(rst_n), .din(din), .dout(start));
        
    
    task automatic drive(input logic v, input int a0, input int a1, input int a2, input int a3, input logic control_start);
        @(posedge clk);
        valid_in     <= v;
        din <= control_start;
        vector_in[0] <= a0;
        vector_in[1] <= a1;
        vector_in[2] <= a2;
        vector_in[3] <= a3;
        
    endtask
    
    // Stimulus
    initial begin
    
    //1. reset
    rst_n = 0;
    w_ld_en = 0;
    w_in_edge = '{default: 0};
    act_in_edge = '{default: 0};
    psum_in_edge = '{default: 0};
    valid_in = 0;
    vector_in = '{0,0,0,0};
    @(negedge clk);
    @(negedge clk);
    rst_n = 1;
    @(negedge clk);
    
    //2. load weights
//    w_ld_en = 1;
//    w_in_edge = '{default: 1};
//    @(negedge clk);
//    w_in_edge = '{default: 2};
//    @(negedge clk);
//    w_in_edge = '{default: 3};
//    @(negedge clk);
//    w_in_edge = '{default: 4};
//    @(negedge clk);
//    w_ld_en = 0;
//    @(negedge clk);
    
//    //3. reset
//    rst_n = 0;
//    @(negedge clk);
//    rst_n = 1;
//    @(negedge clk);
    
    //4. golden array test 
    gen_golden_weights();
    @(negedge clk);
    
    $display("---- Weight load test: N=%0d ----", N);
    for (int r = 0; r < N; r++) begin
        $write("row %0d: ", r);
        for (int c = 0; c < N; c++) $write("%0d ", golden_array[c][r]);
        $display("");
    end    
    load_weights();
    @(negedge clk);
    check_weights();
    
    //5. send through a vector
//    @(negedge clk);
//    for(int i = 0; i < N; i++) begin
//        act_in_edge[i] = i + 1;
//        psum_in_edge[i] = i + 1;
//        @(negedge clk);
//        act_in_edge[i] = i;
//        psum_in_edge[i] = 0;
//    end
        
        drive(1, 1, 2, 3, 4, 1);
        drive(1, 0, 1, 2, 3, 1);
        drive(0, 0, 0, 0, 0, 0);

    #100
    
    
    
    $display("Testbench complete.");
     $finish;
    
    end

endmodule

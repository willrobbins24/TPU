`timescale 1ns / 1ps


module systolic_data_setup #(
    parameter int N = 4,
    parameter int FACTOR_WIDTH = 8 // allocated bits to activation inputs and weights
    
)(
    input logic         clk,     //clock
    input logic         rst_n,   //asynchronous reset
    
    input  logic                          valid_in,
    input logic signed [FACTOR_WIDTH-1:0] vector_in [N],
    output logic signed [FACTOR_WIDTH-1:0] act_edge [N-1:0],
    output logic                          act_edge_valid [N]
    );
    // For row r, chain[r] is an array of r pipeline stages.
    // chain[r][0] is the stage closest to the input; chain[r][r-1] is the
    // stage closest to the output.
    logic [FACTOR_WIDTH-1:0] chain      [N][N];  // chain[row][stage], sized N deep, only [0:r-1] used
    logic                  chain_vld  [N][N];
 
    genvar r, s;
    generate
        for (r = 0; r < N; r++) begin : g_row
 
                // Stage 0 of this row's chain is loaded directly from data_in.
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        chain[r][0]     <= '0;
                        chain_vld[r][0] <= 1'b0;
                    end else begin
                        chain[r][0]     <= vector_in[r];
                        chain_vld[r][0] <= valid_in;
                    end
                end
 
                // Remaining stages shift the previous stage forward each cycle.
                for (s = 1; s <= r; s++) begin : g_stage
                    always_ff @(posedge clk or negedge rst_n) begin
                        if (!rst_n) begin
                            chain[r][s]     <= '0;
                            chain_vld[r][s] <= 1'b0;
                        end else begin
                            chain[r][s]     <= chain[r][s-1];
                            chain_vld[r][s] <= chain_vld[r][s-1];
                        end
                    end
                end
 
                // Output of row r comes from the last stage in its chain.
                always_comb begin
                    act_edge[r]       = chain[r][r];
                    act_edge_valid[r] = chain_vld[r][r];
                end
 
        end
    endgenerate
    
    
endmodule

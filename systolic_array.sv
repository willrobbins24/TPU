`timescale 1ns / 1ps

module systolic_array #(
    parameter int N = 4,
    parameter int FACTOR_WIDTH = 8,
    // Accumulator must be wide enough to sum N products of two FACTOR_WIDTH
    // operands without overflow: 2*FACTOR_WIDTH bits for one product, plus
    // ceil(log2(N)) guard bits for the summation across N terms.
    //parameter int PSUM_WIDTH  = 2*FACTOR_WIDTH + $clog2(N > 1 ? N : 2)
    parameter int PSUM_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,
    
    //weight loading edges
    input logic w_ld_en, // weight load enable for weight loading phase
    input logic signed [FACTOR_WIDTH-1:0] w_in_edge [N-1:0], // North edge for weights
    output logic signed [FACTOR_WIDTH-1:0] w_out_edge [N-1:0], // South edge for weights, unused?
    
    
     // ---- double-buffer swap handshake with the weight_fifo_loader ----
    input  logic tile_ready,     // loader: inactive bank fully loaded, requests swap
    output logic buf_swapped,    // 1-cycle pulse: swap occurred, loader may reuse the freed bank
    output logic active_sel_dbg, // status: which bank is currently active (0/1)
 
    // controller must assert this whenever it drives a REAL/valid new
    // activation+psum column into the array this cycle. Used to track
    // when the pipeline has fully drained so a swap is safe.
    input logic in_valid,
    
    // Controller must control skew of activation inputs
    input logic signed [FACTOR_WIDTH-1:0] act_in_edge [N-1:0], // West edge for activation inputs
    output logic signed [FACTOR_WIDTH-1:0] act_out_edge [N-1:0], // South edge for activation inputs, unused?
    
    // partial sum edges
    // Controller must track outputs
    input logic signed [PSUM_WIDTH-1:0] psum_in_edge  [N-1:0], //North edge for partial sum inputs, unused?
    output logic signed [PSUM_WIDTH-1:0] psum_out_edge  [N-1:0], //South edge for partial sums
    
    // weight debug
    output logic signed [FACTOR_WIDTH-1:0] weight_dbg [N-1:0][N-1:0][1:0]
    );
    
    //internal logic for the web of wires
    logic signed [FACTOR_WIDTH-1:0] act_wire [N:0][N-1:0]; //activation input wires N+1 columns (boundary) N rows
    logic signed [FACTOR_WIDTH-1:0] w_wire [N-1:0][N:0];   //weight wires N columns N+1 rows (boundary)
    logic signed [PSUM_WIDTH-1:0] psum_wire [N-1:0][N:0];  //psum wires N columns N+1 rows (boundary)
   
    // ---------------------------------------------------------------
    // Double-buffer swap control
    // ---------------------------------------------------------------
    logic active_sel;
    logic tile_pending;
    logic [N-1:0] busy_sr;   // 1 bit per pipeline stage, tracks psums in flight
    logic array_busy;
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) busy_sr <= '0;
        else        busy_sr <= {busy_sr[N-2:0], in_valid};
    end
    // busy if a valid column is entering this cycle, or one is still
    // propagating through any of the N pipeline stages
    assign array_busy = in_valid | (|busy_sr);
    
    
    // tile_ready edge detector
    logic tile_ready_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tile_ready_d <= 1'b0;
        else        tile_ready_d <= tile_ready;
    end
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_sel   <= 1'b0;
            tile_pending <= 1'b0;
            buf_swapped  <= 1'b0;
        end else begin
            buf_swapped <= 1'b0; // default: single-cycle pulse
 
            if (tile_ready && !tile_ready_d) tile_pending <= 1'b1;
 
            if (tile_pending && !array_busy) begin
                active_sel   <= ~active_sel;
                tile_pending <= 1'b0;
                buf_swapped  <= 1'b1;
            end
        end
    end
    assign active_sel_dbg = active_sel;
   
    // generate array of processing elements connected via the web of wires
    genvar c, r;
    generate
        for(r = 0; r < N; r++) begin : ROW
            for(c = 0; c < N; c++) begin: COL
            
            pe #(
                .FACTOR_WIDTH(FACTOR_WIDTH),
                .PSUM_WIDTH(PSUM_WIDTH)
                ) processing_element (
                
                .clk(clk),
                .rst_n(rst_n),
                
                .w_in     (w_wire[c][r]),      // from north neighbor (shift in)
                .w_ld_en  (w_ld_en),           // broadcast to every PE
                .w_out    (w_wire[c][r+1]),    // to south neighbor (shift out)
                
                .active_sel (active_sel),      // broadcast, whole-array atomic swap
     
                .act_in   (act_wire[c][r]),    // from west neighbor
                .act_out  (act_wire[c+1][r]),  // to east neighbor
     
                .psum_in  (psum_wire[c][r]),   // from north neighbor
                .psum_out (psum_wire[c][r+1]),  // to south neighbor
            
                .weight_dbg (weight_dbg[c][r])
            );
            
            
            end : COL
        end : ROW
    endgenerate
    
    //boundary conditions
   
    generate
        //East-West boundaries
        for (r = 0; r < N; r++) begin : EAST_WEST_EDGE
            assign act_wire[0][r] = act_in_edge[r];
            assign act_out_edge[r] = act_wire[N][r];
        end : EAST_WEST_EDGE
        
        //North-South boundary
        for(c = 0; c < N; c++) begin : NORTH_SOUTH_EDGE
            //weight boundaries
            assign w_wire[c][0] = w_in_edge[c];
            assign w_out_edge[c] = w_wire[c][N];
            
            //psum boundaries
            assign psum_wire[c][0] = psum_in_edge[c];
            assign psum_out_edge[c] = psum_wire[c][N];
        end : NORTH_SOUTH_EDGE
    endgenerate
    
endmodule

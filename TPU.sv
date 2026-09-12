`timescale 1ns / 1ps

module TPU#(
    parameter int N = 4,
    parameter int FACTOR_WIDTH = 8,
    parameter int PSUM_WIDTH = 32,
    parameter int ADDR_WIDTH = 3,
    parameter int NUM_ACC      = 8,
    parameter int TILE_DEPTH   = 2
)(

input  logic              clk,
input  logic              rst_n,

//data setup
input logic                             valid_in,
input logic signed  [FACTOR_WIDTH-1:0]  vector_in [N],
input logic         [ADDR_WIDTH-1:0]    wr_addr_in,
input logic                             wr_accumulate_in,
//accumulator read
input logic                             rd_en,
input logic         [ADDR_WIDTH-1:0]    rd_addr,
output logic        [PSUM_WIDTH-1:0]    rd_data [N],
output logic                            rd_valid,
//weight loader
input  logic                            wr_valid_in,
input  logic signed [FACTOR_WIDTH-1:0]  wr_data_in,
output logic                            wr_ready,

input logic signed [PSUM_WIDTH-1:0] psum_in_edge  [N-1:0]

);

    
    //array wires
    logic w_ld_en;
    logic signed [FACTOR_WIDTH-1:0] w_in_edge [N-1:0];
    logic signed [FACTOR_WIDTH-1:0] w_out_edge [N-1:0];
    
    logic signed [FACTOR_WIDTH-1:0] act_in_edge [N-1:0];
    logic signed [FACTOR_WIDTH-1:0] act_out_edge [N-1:0];
    
    
    logic signed [PSUM_WIDTH-1:0] psum_out_edge  [N-1:0];
    
    logic tile_ready;
    logic buf_swapped;
    logic active_sel_dbg;

//systolic data setup wires
    logic signed [FACTOR_WIDTH-1:0] syst_act_edge  [N-1:0];
    logic                           act_edge_valid [N];
    logic signed [FACTOR_WIDTH-1:0] weight_dbg [N-1:0][N-1:0][1:0];
    
//deskew wires
    logic                    start;
    logic [ADDR_WIDTH-1:0]   addr_in;
    logic                    accumulate_in;

    logic                    wr_en;
    logic [ADDR_WIDTH-1:0]   wr_addr;
    logic                    wr_accumulate;
    logic signed [PSUM_WIDTH-1:0] wr_data [N-1:0];
    

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
    
logic in_valid;
assign in_valid = act_edge_valid[N-1] | valid_in;
    
//instantiate systolic array
systolic_array #(
        .N(N),
        .FACTOR_WIDTH(FACTOR_WIDTH),
        .PSUM_WIDTH(PSUM_WIDTH)
    )syst_array(
        .clk(clk),
        .rst_n(rst_n),
        .w_ld_en(w_ld_en),
        .w_in_edge(w_in_edge),
        .w_out_edge(w_out_edge),
        .act_in_edge(syst_act_edge),
        .act_out_edge(act_out_edge),
        .psum_in_edge(psum_in_edge),
        .psum_out_edge(psum_out_edge),
        .tile_ready(tile_ready),
        .buf_swapped(buf_swapped),
        .active_sel_dbg(active_sel_dbg),
        .in_valid(in_valid),
        .weight_dbg(weight_dbg)
    );
    
//instantiate control delay for start
control_delay #(
        .WIDTH(1'b1), 
        .DEPTH(N + 1)
    ) start_delay (
        .clk(clk), 
        .rst_n(rst_n), 
        .din(valid_in), 
        .dout(start));
        
//instantiate control delay for address
control_delay #(
        .WIDTH(ADDR_WIDTH), 
        .DEPTH(N + 1)
    ) addr_delay (
        .clk(clk), 
        .rst_n(rst_n), 
        .din(wr_addr_in), 
        .dout(addr_in));

//instantiate control delay for accumulate
control_delay #(
        .WIDTH(1'b1), 
        .DEPTH(N + 1)
    ) accumulate_delay (
        .clk(clk), 
        .rst_n(rst_n), 
        .din(wr_accumulate_in), 
        .dout(accumulate_in));
         
//intantiate deskew
deskew #(
        .N(N), 
        .PSUM_WIDTH(PSUM_WIDTH), 
        .ADDR_WIDTH(ADDR_WIDTH)
    ) deskew (
        .clk(clk), 
        .rst_n(rst_n),
        .start(start), 
        .addr_in(addr_in), 
        .accumulate_in(accumulate_in),
        .array_edge(psum_out_edge),
        .wr_en(wr_en), 
        .wr_addr(wr_addr), 
        .wr_accumulate(wr_accumulate), 
        .wr_data(wr_data)
    );
    
 //instantiate weight loader
 weight_loader#(
    .N(N),
    .FACTOR_WIDTH(FACTOR_WIDTH),
    .TILE_DEPTH(TILE_DEPTH)     // number of full N x N tiles the internal FIFO can hold
)weight_fifo_loader(
    .clk(clk),
    .rst_n(rst_n),
 
    // streaming write side: one weight element per cycle from upstream
    .wr_valid(wr_valid_in),
    .wr_data(wr_data_in),
    .wr_ready(wr_ready),
 
    // load side: drives the systolic array's weight-load edge
    .w_ld_en(w_ld_en),
    .w_in_edge(w_in_edge),
 
    // handshake with systolic_array's double-buffer swap logic
    .tile_ready(tile_ready),   // held high until array acks
    .buf_swapped(buf_swapped)   // 1-cycle pulse from array
);
    
 //instantiate accumulator
 accumulators #(
    .NUM_ACC(NUM_ACC),
    .N(N),
    .PSUM_WIDTH(PSUM_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
    
) accumulator (
    .clk(clk),
    .rst_n(rst_n),
 
    .wr_en(wr_en),
    .wr_addr(wr_addr),
    .wr_accumulate(wr_accumulate),
    .wr_data(wr_data),
    
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .rd_valid(rd_valid)
);

endmodule

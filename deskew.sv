`timescale 1ns / 1ps

module deskew #(
    parameter int N            = 8,  // must match the array width / accumulators' N
    parameter int PSUM_WIDTH = 32,
    parameter int ADDR_WIDTH   = 3   // must match accumulators' $clog2(NUM_ACC)
) (
    input  logic                  clk,
    input  logic                  rst_n,
    
    input  logic                  start,
    input  logic [ADDR_WIDTH-1:0] addr_in,
    input  logic                  accumulate_in,
    input  logic signed [PSUM_WIDTH-1:0] array_edge [N-1:0],

    // ---- De-skewed output: wire straight into accumulators' write port ----
    output logic                  wr_en,
    output logic [ADDR_WIDTH-1:0] wr_addr,
    output logic                  wr_accumulate,
    output logic signed [PSUM_WIDTH-1:0] wr_data [N-1:0]
);

    // ---- Data path: N independent triangular delay chains ----
    genvar g;
    generate
        for (g = 0; g < N; g++) begin : lane_delay
            localparam int DEPTH = N - g;

                logic signed [PSUM_WIDTH-1:0] shift [DEPTH];

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int k = 0; k < DEPTH; k++) shift[k] <= '0;
                    end else begin
                        shift[0] <= array_edge[g];
                        for (int k = 1; k < DEPTH; k++) shift[k] <= shift[k-1];
                    end
                end

                assign wr_data[g] = shift[DEPTH-1];
            end
    endgenerate

    // ---- Control path: addr/accumulate/valid delayed by N-1 to match
    //      the longest data lane (lane 0), so control lines up with
    //      data on the same output cycle. ----
    generate
  
            localparam int CDEPTH = N;

            logic                  valid_sr [CDEPTH];
            logic [ADDR_WIDTH-1:0] addr_sr  [CDEPTH];
            logic                  accum_sr [CDEPTH];

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int k = 0; k < CDEPTH; k++) begin
                        valid_sr[k] <= 1'b0;
                        addr_sr[k]  <= '0;
                        accum_sr[k] <= 1'b0;
                    end
                end else begin
                    valid_sr[0] <= start;
                    addr_sr[0]  <= addr_in;
                    accum_sr[0] <= accumulate_in;
                    for (int k = 1; k < CDEPTH; k++) begin
                        valid_sr[k] <= valid_sr[k-1];
                        addr_sr[k]  <= addr_sr[k-1];
                        accum_sr[k] <= accum_sr[k-1];
                    end
                end
            end

            assign wr_en         = valid_sr[CDEPTH-1];
            assign wr_addr       = addr_sr[CDEPTH-1];
            assign wr_accumulate = accum_sr[CDEPTH-1];
    endgenerate

endmodule

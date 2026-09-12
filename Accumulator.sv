`timescale 1ns / 1ps



module accumulators #(
    parameter int NUM_ACC      = 8,  // number of accumulator addresses (paper: 4096)
    parameter int N            = 8,  // number of lanes / MXU output vector width (paper: 256)
    parameter int PSUM_WIDTH = 32,  // per-lane accumulator width (paper: 32)
    parameter int ADDR_WIDTH = $clog2(NUM_ACC)
) (
    input  logic                       clk,
    input  logic                       rst_n,
 
    // ---- Write port: fed by the MXU (via the de-skew buffer), one vector per cycle ----
    input  logic                       wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic                       wr_accumulate, // 1 = accumulate, 0 = overwrite
    input  logic signed [PSUM_WIDTH-1:0]    wr_data [N-1:0],
 
    // ---- Read port: drained by activation pipeline / unified buffer ----
    input  logic                       rd_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [PSUM_WIDTH-1:0]    rd_data [N],
    output logic                       rd_valid
);
 
    // Behavioral storage: NUM_ACC entries, each N x PSUM_WIDTH.
    logic [PSUM_WIDTH-1:0] mem [NUM_ACC][N];

 
    // ---- Write / accumulate ----
    // The read-modify-write is implicit in the non-blocking assignment:
    // mem[wr_addr][i] on the RHS reads the value already in the array,
    // and the LHS updates it on the same clock edge. That means
    // back-to-back accumulates into the same address on consecutive
    // cycles are correctly ordered (each sees the previous cycle's
    // update).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_ACC; i++)
                mem[i] <= '{default: '0};
        end else if (wr_en) begin
            if (wr_accumulate) begin
                for (int i = 0; i < N; i++)
                    mem[wr_addr][i] <= mem[wr_addr][i] + wr_data[i];
            end else begin
                for (int i = 0; i < N; i++)
                    mem[wr_addr][i] <= wr_data[i];
            end
        end
    end
 
    // ---- Read port (registered, 1-cycle latency) ----
    // If a write and a read target the same address on the same cycle,
    // this returns the pre-write ("old") value, i.e. read-before-write.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid <= 1'b0;
            for (int i = 0; i < N; i++) rd_data[i] <= '0;
        end else begin
            rd_valid <= rd_en;
            if (rd_en)
                for (int i = 0; i < N; i++) rd_data[i] <= mem[rd_addr][i];
        end
    end
 
endmodule

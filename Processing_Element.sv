module pe #(
    parameter int FACTOR_WIDTH = 8, // allocated bits to activation inputs and weights
    parameter int PSUM_WIDTH = 32  // allocated bits to partial sums
    
)(
    input logic         clk,     //clock
    input logic         rst_n,   //asynchronous reset
    input logic signed [FACTOR_WIDTH-1:0]  w_in,    //weight in
    input logic         w_ld_en,    // weight load
    
    input  logic                             active_sel,   // 0 -> bank0 active, 1 -> bank1 active
    
    input logic signed [FACTOR_WIDTH-1:0]  act_in,     // activation in
    input logic signed [PSUM_WIDTH-1:0] psum_in,  // partial sum in
    output logic signed [FACTOR_WIDTH-1:0]  act_out, // activation out
    output logic signed [PSUM_WIDTH-1:0] psum_out,  // partial sum out
    output logic signed [FACTOR_WIDTH-1:0]  w_out, // weight out
    
    // debug: expose both weight banks
    output logic signed [FACTOR_WIDTH-1:0]   weight_dbg [1:0]
);

logic signed [FACTOR_WIDTH-1:0] weight_buf [1:0];

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    weight_buf[0] <= '0;
    weight_buf[1] <= '0;
    psum_out <= '0;
    act_out <= '0;
    w_out <= '0;
    end
  else begin
  if (w_ld_en) begin
    weight_buf[~active_sel] <= w_in;   // <-- only the change: indexed by ~active_sel
    w_out <= w_in;
  end
  psum_out <= psum_in + weight_buf[active_sel] * act_in;
  act_out <= act_in;
  end
end

    assign weight_dbg[0] = weight_buf[0];
    assign weight_dbg[1] = weight_buf[1];

endmodule //pe
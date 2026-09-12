`timescale 1ns / 1ps

module control_delay#(
    parameter int WIDTH = 32,
    parameter int DEPTH = 4
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic [WIDTH-1:0]  din,
    output logic [WIDTH-1:0]  dout
);

    logic [WIDTH-1:0] stages [DEPTH];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                stages[i] <= '0;
            end
        end else begin
            stages[0] <= din;
            for (int i = 1; i < DEPTH; i++) begin
                stages[i] <= stages[i-1];
            end
        end
    end

    assign dout = stages[DEPTH-1];

endmodule

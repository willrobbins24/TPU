`timescale 1ns / 1ps

module weight_loader#(
    parameter int N           = 4,
    parameter int FACTOR_WIDTH = 8,
    parameter int TILE_DEPTH  = 1     // number of full N x N tiles the internal FIFO can hold
)(
    input  logic clk,
    input  logic rst_n,
 
    // streaming write side: one weight element per cycle from upstream
    input  logic                            wr_valid,
    input  logic signed [FACTOR_WIDTH-1:0]  wr_data,
    output logic                            wr_ready,
 
    // load side: drives the systolic array's weight-load edge
    output logic                            w_ld_en,
    output logic signed [FACTOR_WIDTH-1:0]  w_in_edge [N-1:0],
 
    // handshake with systolic_array's double-buffer swap logic
    output logic                            tile_ready,   // held high until array acks
    input  logic                            buf_swapped   // 1-cycle pulse from array
);
 
    localparam int DEPTH = TILE_DEPTH * N;         // storage depth in ROWS
    localparam int AW    = $clog2(DEPTH + 1);
    localparam int EW    = (N > 1) ? $clog2(N) : 1; // width for a 0..N-1 element counter
 
    // -----------------------------------------------------------------
    // serial -> parallel gearbox: accumulate N elements into one row
    // -----------------------------------------------------------------
    logic signed [FACTOR_WIDTH-1:0] row_sr [N-1:0];
    logic [EW-1:0] elem_cnt;
    logic          row_push;   // pulses when a full row has just been assembled
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            elem_cnt <= '0;
            row_push <= 1'b0;
            for (int i = 0; i < N; i++) row_sr[i] <= '0;
        end else begin
            row_push <= 1'b0;
            if (wr_valid && wr_ready) begin
                row_sr[elem_cnt] <= wr_data;
                if (elem_cnt == N-1) begin
                    elem_cnt <= '0;
                    row_push <= 1'b1;
                end else begin
                    elem_cnt <= elem_cnt + 1'b1;
                end
            end
        end
    end
 
    // -----------------------------------------------------------------
    // row FIFO: holds fully-assembled N-wide rows, DEPTH rows deep
    // -----------------------------------------------------------------
    logic signed [FACTOR_WIDTH-1:0] fifo_mem [DEPTH-1:0][N-1:0];
    logic [AW-1:0] wr_ptr, rd_ptr;
    logic [AW-1:0] fifo_cnt;
    logic          fifo_pop;
 
    logic fifo_full;
    assign fifo_full = (fifo_cnt == DEPTH);
    assign wr_ready  = !fifo_full;   // backpressure on the serial input
    
    assign w_in_edge = fifo_mem[rd_ptr];
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            rd_ptr   <= '0;
            fifo_cnt <= '0;
        end else begin
            if (row_push) begin
                fifo_mem[wr_ptr] <= row_sr;
                wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1'b1;
            end
            if (fifo_pop) begin
                rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1'b1;
            end
 
            case ({row_push, fifo_pop})
                2'b10:   fifo_cnt <= fifo_cnt + 1'b1;
                2'b01:   fifo_cnt <= fifo_cnt - 1'b1;
                default: fifo_cnt <= fifo_cnt;
            endcase
        end
    end
 
    // -----------------------------------------------------------------
    // load FSM: once a full tile (N rows) is buffered, shift it out over
    // N cycles, then wait for the array to swap before loading the next
    // -----------------------------------------------------------------
    typedef enum logic [1:0] {IDLE, LOADING, WAIT_SWAP} state_t;
    state_t state;
 
    logic [EW-1:0] load_cnt;
    logic          tile_available;
    assign tile_available = (fifo_cnt >= N);
 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            load_cnt   <= '0;
            w_ld_en    <= 1'b0;
            tile_ready <= 1'b0;
            fifo_pop   <= 1'b0;
        end else begin
            w_ld_en    <= 1'b0;
            tile_ready <= 1'b0;
            fifo_pop   <= 1'b0;
 
            unique case (state)
                IDLE: begin
                    if (tile_available) begin
                        fifo_pop  <= 1'b1;
                        w_ld_en   <= 1'b1;
                        load_cnt  <= 1;
                        state     <= LOADING;
                    end
                end
 
                LOADING: begin
                    w_ld_en   <= 1'b1;
                    fifo_pop  <= 1'b1;
                    load_cnt  <= load_cnt + 1'b1;
                    if (load_cnt == N-1) begin
                        state <= WAIT_SWAP;
                    end
                end
 
                WAIT_SWAP: begin
                    // hold the request until the array confirms the swap;
                    // this also blocks IDLE from starting a new load, so
                    // the freed bank can't be double-booked
                    tile_ready <= 1'b1;
                    if (buf_swapped) state <= IDLE;
                end
 
                default: state <= IDLE;
            endcase
        end
    end
 
endmodule

`timescale 1ps/1ps

module ddr5_read_fifo #(
  parameter int unsigned DATA_WIDTH = 128,
  parameter int unsigned DEPTH      = 4
) (
  input  logic                  ck,
  input  logic                  reset_n,
  input  logic                  push,
  input  logic [DATA_WIDTH-1:0] data_i,
  input  logic                  pop,
  output logic [DATA_WIDTH-1:0] data_o,
  output logic                  valid_o,
  output logic                  full_o,
  output logic                  empty_o
);
  localparam int unsigned PTR_W = $clog2(DEPTH);
  localparam int unsigned CNT_W = PTR_W + 1;

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_W-1:0]      wr_ptr_q, rd_ptr_q;
  logic [CNT_W-1:0]      count_q;

  logic push_ok, pop_ok;
  always_comb begin
    push_ok = push && !full_o;
    pop_ok  = pop  && !empty_o;
  end

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      if (push_ok) begin
        mem[wr_ptr_q] <= data_i;
        wr_ptr_q <= wr_ptr_q + 1'b1;
      end
      if (pop_ok)
        rd_ptr_q <= rd_ptr_q + 1'b1;
      if      (push_ok && !pop_ok)  count_q <= count_q + 1'b1;
      else if (pop_ok  && !push_ok) count_q <= count_q - 1'b1;
    end
  end

  always_comb begin
    data_o  = mem[rd_ptr_q];
    empty_o = (count_q == '0);
    full_o  = (count_q == CNT_W'(DEPTH));
    valid_o = !empty_o;
  end
endmodule

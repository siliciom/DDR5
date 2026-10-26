`timescale 1ps/1ps

module ddr5_write_fifo #(
  parameter int unsigned DQ_WIDTH = 8,
  parameter int unsigned BURST_BEATS = 16
) (
  input  logic                         ck,
  input  logic                         reset_n,
  input  logic                         clear,
  input  logic                         beat_valid,
  input  logic [DQ_WIDTH-1:0]          dq_i,
  input  logic                         dm_n,
  input  logic [5:0]                   beat_i,
  output logic [DQ_WIDTH*BURST_BEATS-1:0] burst_data_o,
  output logic                         burst_valid_o,
  output logic                         busy_o
);
  localparam int unsigned COUNT_W = $clog2(BURST_BEATS + 1);
  logic [DQ_WIDTH*BURST_BEATS-1:0] data_q;
  logic [COUNT_W-1:0] beat_count;
  logic [COUNT_W-1:0] beat_index;

  always_comb begin
    beat_index = beat_i[COUNT_W-1:0];
  end

  always_comb begin
    burst_data_o = data_q;
    burst_valid_o = (beat_count == COUNT_W'(BURST_BEATS));
    busy_o = (beat_count != '0);
  end

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      data_q <= '0;
      beat_count <= '0;
    end else if (clear) begin
      data_q <= '0;
      beat_count <= '0;
    end else if (beat_valid && (beat_i < BURST_BEATS)) begin

      if (beat_i == BURST_BEATS-1)
        beat_count <= COUNT_W'(BURST_BEATS);
      else if (beat_i >= beat_count)
        beat_count <= beat_index + COUNT_W'(1);

      if (dm_n)
        data_q[beat_i*DQ_WIDTH +: DQ_WIDTH] <= dq_i;
    end
  end
endmodule

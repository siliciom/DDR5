`timescale 1ps/1ps

module ddr5_address_map #(
  parameter int unsigned ROW_BITS = 16,
  parameter int unsigned COL_BITS = 10
) (
  input  logic [2:0]              bg_i,
  input  logic [1:0]              ba_i,
  input  logic [ROW_BITS-1:0]     row_i,
  input  logic [COL_BITS-1:0]     col_i,
  output logic [4:0]              bank_o,
  output logic [2:0]              bg_o,
  output logic [1:0]              ba_o,
  output logic [ROW_BITS-1:0]     row_o,
  output logic [COL_BITS-1:0]     col_o
);

  always_comb begin
    bank_o = {bg_i, ba_i};
    bg_o   = bg_i;
    ba_o   = ba_i;
    row_o  = row_i;
    col_o  = col_i;
  end
endmodule

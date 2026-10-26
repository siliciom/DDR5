`timescale 1ps/1ps

module ddr5_column_address_latch (
  input  logic       ck,
  input  logic       reset_n,
  input  logic       load,
  input  logic [9:0] col_i,
  output logic [9:0] col_o
);

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      col_o <= '0;
    end else if (load) begin
      col_o <= col_i;
    end
  end
endmodule

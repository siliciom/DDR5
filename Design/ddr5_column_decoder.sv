`timescale 1ps/1ps

module ddr5_column_decoder (
  input  logic [9:0] start_col,
  input  logic       valid,
  output logic [9:0] decoded_col
);

  always_comb begin
    decoded_col = valid ? start_col : '0;
  end
endmodule

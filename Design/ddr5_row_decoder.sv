`timescale 1ps/1ps

module ddr5_row_decoder (
  input  logic [15:0] row_addr,
  input  logic        row_valid,
  output logic [15:0] selected_row,
  output logic        selected_valid
);

  always_comb begin
    selected_row   = row_addr;
    selected_valid = row_valid;
  end
endmodule

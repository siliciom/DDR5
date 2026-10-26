`timescale 1ps/1ps

module ddr5_read_data_path (
  input  logic [127:0] data_i,
  input  logic [5:0]   beat_i,
  input  logic         valid_i,
  output logic [7:0]   data_o
);

  always_comb begin
    data_o = 8'h00;
    if (valid_i && (beat_i < 6'd16)) data_o = data_i[beat_i*8 +: 8];
  end
endmodule

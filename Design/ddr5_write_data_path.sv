`timescale 1ps/1ps

module ddr5_write_data_path (
  input  logic [127:0] data_i,
  input  logic [7:0]   dq_i,
  input  logic [5:0]   beat_i,
  input  logic         valid_i,
  input  logic         dm_n,
  output logic [127:0] data_o
);

  always_comb begin
    data_o = data_i;
    if (valid_i && dm_n && (beat_i < 6'd16))
      data_o[beat_i*8 +: 8] = dq_i;
  end
endmodule

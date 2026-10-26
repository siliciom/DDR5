`timescale 1ps/1ps

module ddr5_mode_register_file #(
  parameter int unsigned MR_COUNT = 256
) (
  input  logic       ck,
  input  logic       reset_n,
  input  logic       wr_valid,
  input  logic [7:0] wr_addr,
  input  logic [7:0] wr_data,
  input  logic       rd_valid,
  input  logic [7:0] rd_addr,
  output logic [7:0] rd_data,
  output logic       mode_2n,
  output logic [1:0] burst_length,
  output logic       crc_enable,
  output logic       ecc_enable,
  output logic       fgr_enable,
  output logic       rfm_enable,
  output logic       write_leveling_enable,
  output logic       read_training_enable,
  output logic       mpsm_enable,
  output logic [7:0] vrefca_code,
  output logic [7:0] vrefca_value,
  output logic [7:0] vrefcs_value,
  output logic [7:0] vrefdq_value,
  output logic [7:0] mr32_odt,
  output logic [7:0] mr33_odt
);
  logic [7:0] mr [0:MR_COUNT-1];
  integer i;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin

      for (i = 0; i < MR_COUNT; i = i + 1) mr[i] <= 8'h00;

      mr[10] <= 8'h2D;
      mr[11] <= 8'h2D;
      mr[12] <= 8'h2D;
      mr[15] <= 8'h03;
    end else if (wr_valid && (wr_addr < MR_COUNT)) begin
      mr[wr_addr] <= wr_data;
    end
  end

  always_comb begin
    rd_data              = rd_valid ? mr[rd_addr] : 8'h00;
    burst_length         = mr[0][1:0];
    mode_2n              = mr[2][2];
    write_leveling_enable= mr[2][1];
    read_training_enable = mr[2][0];
    mpsm_enable          = mr[2][3];
    vrefdq_value         = mr[10];
    vrefca_value         = mr[11];
    vrefcs_value         = mr[12];
    mr32_odt             = mr[32];
    mr33_odt             = mr[33];
    crc_enable           = mr[50][0];
    ecc_enable           = 1'b1;
    fgr_enable           = (mr[3][1:0] != 2'b00);
    rfm_enable           = (mr[58] != 8'h00);
    vrefca_code          = mr[11];
  end
endmodule

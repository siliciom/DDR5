`timescale 1ps/1ps

module ddr5_phy_digital #(
  parameter int unsigned DQ_WIDTH = 8
) (
  input  logic                  tx_valid_i,
  input  logic [DQ_WIDTH-1:0]  tx_data_i,
  input  logic                  rx_valid_i,
  input  logic [DQ_WIDTH-1:0]  rx_data_i,
  input  logic                  dqs_i,
  input  logic [1:0]            read_preamble,
  input  logic [1:0]            write_preamble,
  output logic                  tx_valid_o,
  output logic [DQ_WIDTH-1:0]  tx_data_o,
  output logic                  rx_valid_o,
  output logic [DQ_WIDTH-1:0]  rx_data_o,
  output logic                  dqs_sample_o
);

  always_comb begin
    tx_valid_o  = tx_valid_i;
    tx_data_o   = tx_data_i;
    rx_valid_o  = rx_valid_i;
    rx_data_o   = rx_data_i;
    dqs_sample_o = dqs_i;
  end
endmodule

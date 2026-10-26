`timescale 1ps/1ps

module ddr5_io_gating (
  input  logic tx_req,
  input  logic rx_req,
  input  logic phy_tx_oe,
  output logic tx_enable,
  output logic rx_enable,
  output logic turnaround_conflict
);

  always_comb begin
    turnaround_conflict = tx_req && rx_req;
    tx_enable = tx_req && !rx_req && phy_tx_oe;
    rx_enable = rx_req && !tx_req;
  end
endmodule

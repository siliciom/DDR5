`timescale 1ps/1ps

module ddr5_dq_driver #(
  parameter int unsigned DQ_WIDTH = 8
) (
  input  logic                  ck,
  input  logic                  reset_n,
  input  logic                  tx_enable,
  input  logic [DQ_WIDTH-1:0]  tx_data,
  input  logic                  dqs_enable,
  output logic [DQ_WIDTH-1:0]  dq_o,
  output logic                 dq_oe,
  output logic                 dqs_t_o,
  output logic                 dqs_c_o,
  output logic                 dqs_oe
);
  logic dqs_phase_q;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      dq_o <= '0;
      dq_oe <= 1'b0;
      dqs_t_o <= 1'b0;
      dqs_c_o <= 1'b1;
      dqs_oe <= 1'b0;
      dqs_phase_q <= 1'b0;
    end else begin
      dq_oe <= tx_enable;
      dqs_oe <= dqs_enable;
      if (tx_enable) dq_o <= tx_data;
      if (dqs_enable) begin
        dqs_phase_q <= ~dqs_phase_q;
        dqs_t_o <= dqs_phase_q;
        dqs_c_o <= ~dqs_phase_q;
      end
    end
  end
endmodule

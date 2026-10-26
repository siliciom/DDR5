`timescale 1ps/1ps

module ddr5_dq_receiver #(
  parameter int unsigned DQ_WIDTH = 8
) (
  input  logic                  ck,
  input  logic                  reset_n,
  input  logic                  rx_enable,
  input  logic [DQ_WIDTH-1:0]  dq_i,
  input  logic                  dqs_i,
  output logic [DQ_WIDTH-1:0]  dq_o,
  output logic                  valid_o,
  output logic                  dqs_sample_o
);

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      dq_o <= '0;
      valid_o <= 1'b0;
      dqs_sample_o <= 1'b0;
    end else begin
      valid_o <= 1'b0;
      if (rx_enable) begin
        dq_o <= dq_i;
        dqs_sample_o <= dqs_i;

        valid_o <= (dqs_i !== 1'bz);
      end
    end
  end
endmodule

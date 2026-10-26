`timescale 1ps/1ps

module ddr5_alert_controller (
  input  logic ck,
  input  logic reset_n,
  input  logic crc_error,
  input  logic ecc_error,
  input  logic training_error,
  output logic alert_n
);
  logic sticky_q;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      sticky_q <= 1'b0;
      alert_n <= 1'b1;
    end else if (crc_error || ecc_error || training_error) begin
      sticky_q <= 1'b1;
      alert_n <= 1'b0;
    end else begin
      alert_n <= !sticky_q;
    end
  end
endmodule

`timescale 1ps/1ps

module ddr5_power_controller (
  input  logic ck,
  input  logic reset_n,
  input  logic sre,
  input  logic sref,
  input  logic srx,
  input  logic pde,
  input  logic pdx,
  output logic self_refresh,
  output logic freq_change_mode,
  output logic power_down
);

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      self_refresh <= 1'b0;
      freq_change_mode <= 1'b0;
      power_down <= 1'b0;
    end else begin

      if      (srx)  begin self_refresh <= 1'b0; freq_change_mode <= 1'b0; end
      else if (sref) begin self_refresh <= 1'b1; freq_change_mode <= 1'b1; end
      else if (sre)  begin self_refresh <= 1'b1; freq_change_mode <= 1'b0; end

      if      (pdx) power_down <= 1'b0;
      else if (pde) power_down <= 1'b1;
    end
  end
endmodule

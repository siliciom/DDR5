`timescale 1ps/1ps

module ddr5_mpc_controller (
  input  logic ck,
  input  logic reset_n,
  input  logic valid,
  input  logic [7:0] op,
  output logic zq_start,
  output logic zq_latch,
  output logic dll_reset,
  output logic enter_ca_training,
  output logic enter_cs_training,
  output logic exit_cs_training,
  output logic set_2n,
  output logic set_1n,
  output logic manual_ecs,
  output logic dqs_osc_start,
  output logic dqs_osc_stop,
  output logic apply_vref_odt
);

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      zq_start <= 1'b0; zq_latch <= 1'b0; dll_reset <= 1'b0;
      enter_ca_training <= 1'b0; enter_cs_training <= 1'b0; exit_cs_training <= 1'b0;
      set_2n <= 1'b0; set_1n <= 1'b0; manual_ecs <= 1'b0;
      dqs_osc_start <= 1'b0; dqs_osc_stop <= 1'b0; apply_vref_odt <= 1'b0;
    end else begin
      zq_start <= 1'b0; zq_latch <= 1'b0; dll_reset <= 1'b0;
      enter_ca_training <= 1'b0; enter_cs_training <= 1'b0; exit_cs_training <= 1'b0;
      set_2n <= 1'b0; set_1n <= 1'b0; manual_ecs <= 1'b0;
      dqs_osc_start <= 1'b0; dqs_osc_stop <= 1'b0; apply_vref_odt <= 1'b0;
      if (valid) begin
        case (op)
          8'h00: exit_cs_training <= 1'b1;
          8'h01: enter_cs_training <= 1'b1;
          8'h02: dll_reset <= 1'b1;
          8'h03: enter_ca_training <= 1'b1;
          8'h04: zq_latch <= 1'b1;
          8'h05: zq_start <= 1'b1;
          8'h06: dqs_osc_stop <= 1'b1;
          8'h07: dqs_osc_start <= 1'b1;
          8'h08: set_2n <= 1'b1;
          8'h09: set_1n <= 1'b1;
          8'h0C: manual_ecs <= 1'b1;
          8'h1F: apply_vref_odt <= 1'b1;
          default: begin end
        endcase
      end
    end
  end
endmodule

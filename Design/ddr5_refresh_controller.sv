`timescale 1ps/1ps

module ddr5_refresh_controller #(
  parameter int unsigned TREFI = 9375,
  parameter int unsigned TRFC  = 710
) (
  input  logic        ck,
  input  logic        reset_n,
  input  logic        enable,
  input  logic        refab_cmd,
  input  logic        refsb_cmd,
  input  logic        rfmab_cmd,
  input  logic        rfmsb_cmd,
  input  logic [1:0]  ba,
  input  logic        fgr_enable,
  input  logic        rfm_enable,
  output logic        refresh_due,
  output logic        refresh_busy,
  output logic [15:0] refresh_row,
  output logic [31:0] same_bank_counter,
  output logic        refresh_error
);
  logic [31:0] ref_count;
  logic [31:0] rfc_count;
  logic [15:0] sb_row [0:3];
  integer i;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      ref_count <= '0;
      rfc_count <= '0;
      refresh_due <= 1'b0;
      refresh_busy <= 1'b0;
      refresh_row <= '0;
      same_bank_counter <= '0;
      refresh_error <= 1'b0;
      for (i = 0; i < 4; i = i + 1) sb_row[i] <= '0;
    end else if (enable) begin
      if (ref_count >= TREFI-1) begin
        ref_count <= '0;
        refresh_due <= 1'b1;
      end else begin
        ref_count <= ref_count + 1'b1;
      end

      if (refresh_busy) begin
        if (rfc_count >= TRFC-1) begin
          refresh_busy <= 1'b0;
          rfc_count <= '0;
        end else begin
          rfc_count <= rfc_count + 1'b1;
        end
      end

      if (refab_cmd || (refsb_cmd && fgr_enable) || (rfmab_cmd && rfm_enable) || (rfmsb_cmd && rfm_enable)) begin
        if (refresh_busy) begin
          refresh_error <= 1'b1;
        end else begin
          refresh_busy <= 1'b1;
          rfc_count <= '0;
          ref_count <= '0;
          refresh_due <= 1'b0;
          if (refsb_cmd || rfmsb_cmd) begin
            refresh_row <= sb_row[ba];
            sb_row[ba] <= sb_row[ba] + 1'b1;
            same_bank_counter <= same_bank_counter + 1'b1;
          end else begin
            refresh_row <= refresh_row + 1'b1;
          end
        end
      end
    end
  end
endmodule

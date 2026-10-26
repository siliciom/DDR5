`timescale 1ps/1ps

module ddr5_timing_manager #(
  parameter int unsigned T_RCD      = 39,
  parameter int unsigned T_RP       = 39,
  parameter int unsigned T_RAS      = 77,
  parameter int unsigned T_RC       = 117,
  parameter int unsigned T_RRD_S    = 8,
  parameter int unsigned T_RRD_L    = 13,
  parameter int unsigned T_FAW      = 32,
  parameter int unsigned T_CCD_S    = 8,
  parameter int unsigned T_CCD_L    = 13,
  parameter int unsigned T_CCD_L_WR = 49,
  parameter int unsigned T_WR       = 72,
  parameter int unsigned T_RTP      = 19,
  parameter int unsigned T_WTR_S    = 52,
  parameter int unsigned T_WTR_L    = 70,
  parameter int unsigned T_RFC      = 710,
  parameter int unsigned T_MRD      = 16
) (
  input  logic        ck,
  input  logic        reset_n,
  input  logic        act_cmd,
  input  logic        rd_cmd,
  input  logic        wr_cmd,
  input  logic        pre_cmd,
  input  logic        ref_cmd,
  input  logic        mr_cmd,
  input  logic [2:0]  bg,
  input  logic [4:0]  bank,
  input  logic        bank_active,
  output logic        legal_act,
  output logic        legal_rd,
  output logic        legal_wr,
  output logic        legal_pre,
  output logic        legal_ref,
  output logic        legal_mr,
  output logic        tfaw_violation,
  output logic        timing_error,
  output logic        illegal_act,
  output logic        illegal_rd,
  output logic        illegal_wr,
  output logic        illegal_pre
);
  localparam logic [31:0] AGE_INF = 32'hFFFF_FFFF;
  logic [31:0] bank_age    [0:31];
  logic [31:0] pre_age     [0:31];
  logic [31:0] bg_age      [0:7];
  logic [31:0] wr_bg_age   [0:7];
  logic [31:0] act_hist    [0:3];
  logic [31:0] last_act_age, cas_age, wr_age, rd_age, ref_age, mr_age;
  logic [2:0]  last_act_bg, last_cas_bg;
  logic        last_cas_valid, last_was_write, last_was_read;
  logic [1:0]  hist_ptr;
  integer i;
  integer j;

  function automatic logic [31:0] u32(input int unsigned value);
    u32 = value;
  endfunction

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      for (i = 0; i < 32; i = i + 1) begin
        bank_age[i] <= AGE_INF;
        pre_age[i] <= AGE_INF;
      end
      for (i = 0; i < 8; i = i + 1) begin
        bg_age[i]    <= AGE_INF;
        wr_bg_age[i] <= AGE_INF;
      end
      for (i = 0; i < 4; i = i + 1) begin
        act_hist[i] <= AGE_INF;
      end
      last_act_age <= AGE_INF;
      cas_age <= AGE_INF;
      wr_age <= AGE_INF;
      rd_age <= AGE_INF;
      ref_age <= AGE_INF;
      mr_age <= AGE_INF;
      last_act_bg <= '0;
      last_cas_bg <= '0;
      last_cas_valid <= 1'b0;
      last_was_write <= 1'b0;
      last_was_read <= 1'b0;
      hist_ptr <= '0;
    end else begin
      for (i = 0; i < 32; i = i + 1) begin
        if (bank_age[i] != AGE_INF) bank_age[i] <= bank_age[i] + 32'd1;
        if (pre_age[i] != AGE_INF) pre_age[i] <= pre_age[i] + 32'd1;
      end
      for (i = 0; i < 8; i = i + 1) begin
        if (bg_age[i]    != AGE_INF) bg_age[i]    <= bg_age[i]    + 32'd1;
        if (wr_bg_age[i] != AGE_INF) wr_bg_age[i] <= wr_bg_age[i] + 32'd1;
      end
      for (i = 0; i < 4; i = i + 1) begin
        if (act_hist[i] != AGE_INF) act_hist[i] <= act_hist[i] + 32'd1;
      end
      if (last_act_age != AGE_INF) last_act_age <= last_act_age + 32'd1;
      if (cas_age != AGE_INF) cas_age <= cas_age + 32'd1;
      if (wr_age != AGE_INF) wr_age <= wr_age + 32'd1;
      if (rd_age != AGE_INF) rd_age <= rd_age + 32'd1;
      if (ref_age != AGE_INF) ref_age <= ref_age + 32'd1;
      if (mr_age != AGE_INF) mr_age <= mr_age + 32'd1;

      if (act_cmd) begin
        bank_age[bank] <= 32'd0;
        bg_age[bg] <= 32'd0;
        pre_age[bank] <= AGE_INF;
        last_act_age <= 32'd0;
        last_act_bg <= bg;
        act_hist[hist_ptr] <= 32'd0;
        hist_ptr <= hist_ptr + 2'd1;
      end
      if (pre_cmd) pre_age[bank] <= 32'd0;
      if (rd_cmd || wr_cmd) begin
        cas_age <= 32'd0;
        last_cas_bg <= bg;
        last_cas_valid <= 1'b1;
      end
      if (wr_cmd) begin
        wr_age <= 32'd0;
        wr_bg_age[bg] <= 32'd0;
        last_was_write <= 1'b1;
        last_was_read <= 1'b0;
      end
      if (rd_cmd) begin
        rd_age <= 32'd0;
        last_was_write <= 1'b0;
        last_was_read <= 1'b1;
      end
      if (ref_cmd) ref_age <= 32'd0;
      if (mr_cmd) mr_age <= 32'd0;
    end
  end

  always_comb begin

    tfaw_violation = 1'b0;
    for (j = 0; j < 4; j = j + 1) begin
      if (act_hist[j] < u32(T_FAW)) tfaw_violation = 1'b1;
    end

    legal_act = !bank_active
              && !tfaw_violation
              && ((pre_age[bank] >= u32(T_RP)) || (pre_age[bank] == AGE_INF))
              && ((bank_age[bank] >= u32(T_RC)) || (bank_age[bank] == AGE_INF))
              && ((last_act_age >= u32((last_act_bg == bg) ? T_RRD_L : T_RRD_S)) || (last_act_age == AGE_INF))
              && ((bg_age[bg] >= u32((last_act_bg == bg) ? T_RRD_L : T_RRD_S)) || (bg_age[bg] == AGE_INF));

    legal_pre = bank_active
              && (bank_age[bank] >= u32(T_RAS))
              && (!last_was_write || (wr_age >= u32(T_WR)));

    legal_rd = bank_active
             && (bank_age[bank] >= u32(T_RCD))
             && (!last_cas_valid || (cas_age >= u32((last_cas_bg == bg) ? T_CCD_L : T_CCD_S)))
             && ((ref_age >= u32(T_RFC)) || (ref_age == AGE_INF))
             && (!last_was_write || (wr_age >= u32((last_cas_bg == bg) ? T_WTR_L : T_WTR_S)));

    legal_wr = bank_active
             && (bank_age[bank] >= u32(T_RCD))
             && (!last_cas_valid || (cas_age >= u32((last_cas_bg == bg) ? T_CCD_L : T_CCD_S)))
             && ((wr_bg_age[bg] >= u32(T_CCD_L_WR)) || (wr_bg_age[bg] == AGE_INF))
             && ((ref_age >= u32(T_RFC)) || (ref_age == AGE_INF))
             && (!last_was_read || (rd_age >= u32(T_RTP)));

    legal_ref = (ref_age >= u32(T_RFC)) || (ref_age == AGE_INF);
    legal_mr  = (mr_age >= u32(T_MRD)) || (mr_age == AGE_INF);

    illegal_act = act_cmd && !legal_act;
    illegal_rd  = rd_cmd  && !legal_rd;
    illegal_wr  = wr_cmd  && !legal_wr;
    illegal_pre = pre_cmd && !legal_pre;
    timing_error = illegal_act || illegal_rd || illegal_wr || illegal_pre;
  end
endmodule

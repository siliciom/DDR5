`timescale 1ps/1ps

module ddr5_sdram_sanity #(
  parameter int unsigned SPEED_GRADE = 4800,
  parameter int unsigned DENSITY_GB  = 16,
  parameter bit          ENABLE_BL32 = 1'b0
) (
  input  logic        ck_t,
  input  logic        ck_c,
  input  logic        reset_n,
  input  logic        cs_n,
  input  logic [13:0] ca,
  inout  wire  [7:0]  dq,
  inout  wire         dqs_t,
  inout  wire         dqs_c,
  input  logic        dm_n,
  input  logic        vrefca,
  input  logic        vrefdq,
  input  logic        zq,
  output logic        alert_n
);
  import ddr5_pkg::*;
  import ddr5_speed_profile::*;

  logic [13:0] ca1, ca2;
  logic cs1, cs2, pair_valid;
  logic [2:0]  bg, map_bg;
  logic [1:0]  ba, map_ba;
  logic [4:0]  bank_id, map_bank;
  logic [15:0] row, map_row;
  logic [9:0]  col, map_col;
  logic [7:0]  mr_addr, mr_data, mpc_op;
  logic        ap;
  ddr5_cmd_e   cmd;
  logic        cmd_valid;

  logic [31:0] active, rowbuf_valid;
  logic [15:0] open_row  [0:31];
  logic [15:0] rowbuf_open [0:31];
  logic legal_act, legal_rd, legal_wr, legal_pre, timing_error;
  logic mode_2n, crc_en, fgr_en, rfm_en, wl_en, rt_en;
  logic [1:0]  bl_mode;
  logic [7:0]  vca, vcs, vdq, mr32, mr33;

  logic refresh_error, self_refresh, power_down;
  logic train_done, train_error, odt_active, zq_done;
  logic mpc_zq_start, mpc_dll_reset, mpc_ecs;
  logic init_done, issue_zq, issue_training;

  logic [15:0] row_decoded;
  logic row_decoded_valid;
  logic [9:0]  col_latched, col_decoded;
  logic [127:0] mem_read, read_word, read_fifo_data, write_fifo_data, write_merged;
  logic [9:0]  mem_col;
  logic mem_re, mem_we;
  logic [7:0]  read_byte;
  logic [5:0]  beat;
  logic [9:0]  burst_col;
  logic burst_done, read_active, write_active;
  logic [5:0]  read_delay, write_delay;
  logic wr_fifo_valid, wr_fifo_clear;
  logic rd_fifo_valid, rd_fifo_full;

  logic [5:0] wr_beat;
  logic auto_precharge_event;
  logic [4:0] auto_precharge_bank;
  logic ap_active_q;
  logic [4:0] ap_bank_q;

  logic issue_zq_r;
  logic zq_trigger;

  always_ff @(posedge ck_t or negedge reset_n)
    if (!reset_n) issue_zq_r <= 1'b0;
    else          issue_zq_r <= issue_zq;
  assign zq_trigger = issue_zq && !issue_zq_r;

  logic clock_pair_error, row_state_error;
  assign clock_pair_error = (ck_t == ck_c);
  assign row_state_error  = active[bank_id] && rowbuf_valid[bank_id] &&
                            (open_row[bank_id] != rowbuf_open[bank_id]);
  assign bank_id = map_bank;

  logic [7:0] dq_rx_data, dq_tx_data;
  logic dq_rx_valid, dq_rx_dqs;
  logic dq_drv_oe, dq_drv_dqs_t, dq_drv_dqs_c, dq_drv_dqs_oe;
  logic io_tx_enable, io_rx_enable;
  logic phy_tx_valid, phy_rx_valid, phy_dqs_sample;
  logic [7:0] phy_tx_data, phy_rx_data;
  logic [7:0] dq_sample;

  ddr5_cmd_capture u_cmd_capture (
    .ck(ck_t), .reset_n(reset_n), .cs_n(cs_n), .ca(ca), .mode_2n(mode_2n),
    .pair_valid(pair_valid), .ca1(ca1), .ca2(ca2), .cs1(cs1), .cs2(cs2)
  );

  ddr5_command_decoder u_command_decoder (
    .ca1(ca1), .ca2(ca2), .cs1(cs1), .cs2(cs2),
    .power_down_state(power_down), .self_refresh_state(self_refresh),
    .cmd(cmd), .valid(cmd_valid), .bg(bg), .ba(ba), .row(row), .col(col),
    .mr_addr(mr_addr), .mr_data(mr_data), .auto_precharge(ap),
    .partial_write(), .mpc_op(mpc_op), .vref_op(), .pre_mode()
  );

  ddr5_address_map u_address_map (
    .bg_i(bg), .ba_i(ba), .row_i(row), .col_i(col),
    .bank_o(map_bank), .bg_o(map_bg), .ba_o(map_ba), .row_o(map_row), .col_o(map_col)
  );

  ddr5_timing_manager #(
    .T_RCD(T_RCD), .T_RP(T_RP), .T_RAS(T_RAS), .T_RC(T_RC),
    .T_RRD_S(T_RRD_S), .T_RRD_L(T_RRD_L), .T_FAW(T_FAW),
    .T_CCD_S(T_CCD_S), .T_CCD_L(T_CCD_L), .T_CCD_L_WR(T_CCD_L_WR),
    .T_WR(T_WR), .T_RTP(T_RTP),
    .T_WTR_S(T_WTR_S), .T_WTR_L(T_WTR_L), .T_RFC(T_RFC1), .T_MRD(T_MRD)
  ) u_timing_manager (
    .ck(ck_t), .reset_n(reset_n),
    .act_cmd(pair_valid && cmd_valid && (cmd == CMD_ACT)),
    .rd_cmd(pair_valid && cmd_valid && ((cmd == CMD_RD) || (cmd == CMD_RDA))),
    .wr_cmd(pair_valid && cmd_valid && ((cmd == CMD_WR) || (cmd == CMD_WRA) ||
                                        (cmd == CMD_WRP) || (cmd == CMD_WRPA))),
    .pre_cmd(pair_valid && cmd_valid && ((cmd == CMD_PREPB) || (cmd == CMD_PRESB))),
    .ref_cmd(pair_valid && cmd_valid && ((cmd == CMD_REFAB) || (cmd == CMD_REFSB) ||
                                         (cmd == CMD_RFMAB) || (cmd == CMD_RFMSB))),
    .mr_cmd(pair_valid && cmd_valid && ((cmd == CMD_MRW) || (cmd == CMD_MRR))),
    .bg(map_bg), .bank(bank_id), .bank_active(active[bank_id]),
    .legal_act(legal_act), .legal_rd(legal_rd), .legal_wr(legal_wr),
    .legal_pre(legal_pre), .legal_ref(), .legal_mr(),
    .tfaw_violation(), .timing_error(timing_error),
    .illegal_act(), .illegal_rd(), .illegal_wr(), .illegal_pre()
  );

  ddr5_bank_controller u_bank_controller (
    .ck(ck_t), .reset_n(reset_n),
    .act_valid(pair_valid && cmd_valid && (cmd == CMD_ACT) && legal_act && row_decoded_valid),
    .act_bank(bank_id), .act_row(row_decoded),
    .pre_pb(pair_valid && cmd_valid && (cmd == CMD_PREPB) && legal_pre),
    .pre_sb(pair_valid && cmd_valid && (cmd == CMD_PRESB) && legal_pre),
    .pre_ab(pair_valid && cmd_valid && (cmd == CMD_PREAB)),
    .pre_bank(bank_id), .auto_precharge_event(auto_precharge_event),
    .auto_precharge_bank(auto_precharge_bank), .active(active), .open_row(open_row),
    .act_legal(), .pre_legal()
  );

  ddr5_row_buffer u_row_buffer (
    .ck(ck_t), .reset_n(reset_n),
    .act_valid(pair_valid && cmd_valid && (cmd == CMD_ACT) && legal_act && row_decoded_valid),
    .act_bank(bank_id), .act_row(row_decoded),
    .pre_pb(pair_valid && cmd_valid && (cmd == CMD_PREPB) && legal_pre),
    .pre_sb(pair_valid && cmd_valid && (cmd == CMD_PRESB) && legal_pre),
    .pre_ab(pair_valid && cmd_valid && (cmd == CMD_PREAB)),
    .pre_bank(bank_id), .auto_precharge_event(auto_precharge_event),
    .auto_precharge_bank(auto_precharge_bank), .row_valid(rowbuf_valid),
    .open_row(rowbuf_open)
  );

  ddr5_row_decoder u_row_decoder (
    .row_addr(map_row), .row_valid(legal_act),
    .selected_row(row_decoded), .selected_valid(row_decoded_valid)
  );

  ddr5_column_address_latch u_column_latch (
    .ck(ck_t), .reset_n(reset_n),
    .load(pair_valid && cmd_valid && ((cmd == CMD_RD) || (cmd == CMD_RDA) ||
                                      (cmd == CMD_WR) || (cmd == CMD_WRA) ||
                                      (cmd == CMD_WRP) || (cmd == CMD_WRPA))),
    .col_i(map_col), .col_o(col_latched)
  );

  ddr5_column_decoder u_column_decoder (
    .start_col(col_latched), .valid(read_active || write_active),
    .decoded_col(col_decoded)
  );

  ddr5_mode_register_file u_mode_register_file (
    .ck(ck_t), .reset_n(reset_n),
    .wr_valid(pair_valid && cmd_valid && (cmd == CMD_MRW)),
    .wr_addr(mr_addr), .wr_data(mr_data),
    .rd_valid(pair_valid && cmd_valid && (cmd == CMD_MRR)),
    .rd_addr(mr_addr), .rd_data(),
    .mode_2n(mode_2n), .burst_length(bl_mode), .crc_enable(crc_en), .ecc_enable(),
    .fgr_enable(fgr_en), .rfm_enable(rfm_en), .write_leveling_enable(wl_en),
    .read_training_enable(rt_en), .mpsm_enable(), .vrefca_code(),
    .vrefca_value(vca), .vrefcs_value(vcs), .vrefdq_value(vdq),
    .mr32_odt(mr32), .mr33_odt(mr33)
  );

  ddr5_burst_controller u_burst_controller (
    .start_col(col_decoded), .burst_mode(bl_mode), .read_mode(read_active),
    .enable_bl32(ENABLE_BL32), .beat(beat), .burst_col(burst_col),
    .burst_done(burst_done)
  );

  assign mem_col = mem_re ? map_col : col_latched;
  assign mem_re  = pair_valid && cmd_valid && !self_refresh && !power_down && init_done &&
                   ((cmd == CMD_RD) || (cmd == CMD_RDA)) && legal_rd && active[bank_id];

  ddr5_memory_array #(
    .MODEL_BANKS(NUM_BANKS), .MODEL_ROWS(64), .MODEL_COLS(64)
  ) u_memory_array (
    .ck(ck_t), .write_en(mem_we), .read_en(mem_re), .bank(bank_id),
    .row(open_row[bank_id]), .col(mem_col),
    .write_data(write_merged), .write_ecc(16'h0000),
    .read_data(mem_read),      .read_ecc()
  );

  ddr5_read_fifo u_read_fifo (
    .ck(ck_t), .reset_n(reset_n),
    .push(mem_re && !rd_fifo_full), .data_i(mem_read),
    .pop(read_active && (read_delay == 0) && burst_done),
    .data_o(read_fifo_data), .valid_o(rd_fifo_valid),
    .full_o(rd_fifo_full), .empty_o()
  );

  ddr5_read_data_path u_read_data_path (
    .data_i(read_fifo_data), .beat_i(beat),
    .valid_i(read_active && (read_delay == 0) && rd_fifo_valid), .data_o(read_byte)
  );

  ddr5_write_fifo u_write_fifo (
    .ck(ck_t), .reset_n(reset_n), .clear(wr_fifo_clear), .beat_valid(phy_rx_valid),
    .dq_i(phy_rx_data), .dm_n(dm_n), .beat_i(wr_beat),
    .burst_data_o(write_fifo_data), .burst_valid_o(wr_fifo_valid), .busy_o()
  );

  ddr5_write_data_path u_write_data_path (
    .data_i(write_fifo_data), .dq_i(phy_rx_data), .beat_i(wr_beat),
    .valid_i(1'b0), .dm_n(dm_n), .data_o(write_merged)
  );

  ddr5_phy_digital u_phy_digital (
    .tx_valid_i(read_active && (read_delay == 0)), .tx_data_i(read_byte),
    .rx_valid_i(dq_rx_valid), .rx_data_i(dq_rx_data), .dqs_i(dq_rx_dqs),
    .read_preamble(2'd1), .write_preamble(2'd2),
    .tx_valid_o(phy_tx_valid), .tx_data_o(phy_tx_data),
    .rx_valid_o(phy_rx_valid), .rx_data_o(phy_rx_data), .dqs_sample_o(phy_dqs_sample)
  );

  ddr5_io_gating u_io_gating (
    .tx_req(phy_tx_valid),
    .rx_req(write_active && (write_delay == 0)),
    .phy_tx_oe(phy_tx_valid),
    .tx_enable(io_tx_enable), .rx_enable(io_rx_enable), .turnaround_conflict()
  );

  ddr5_dq_receiver u_dq_receiver (
    .ck(ck_t), .reset_n(reset_n), .rx_enable(io_rx_enable), .dq_i(dq_sample),
    .dqs_i(dqs_t), .dq_o(dq_rx_data), .valid_o(dq_rx_valid), .dqs_sample_o(dq_rx_dqs)
  );

  ddr5_dq_driver u_dq_driver (
    .ck(ck_t), .reset_n(reset_n), .tx_enable(io_tx_enable), .tx_data(phy_tx_data),
    .dqs_enable(io_tx_enable), .dq_o(dq_tx_data), .dq_oe(dq_drv_oe),
    .dqs_t_o(dq_drv_dqs_t), .dqs_c_o(dq_drv_dqs_c), .dqs_oe(dq_drv_dqs_oe)
  );


  assign dq        = dq_drv_oe     ? dq_tx_data   : 8'bz;
  assign dqs_t     = dq_drv_dqs_oe ? dq_drv_dqs_t : 1'bz;
  assign dqs_c     = dq_drv_dqs_oe ? dq_drv_dqs_c : 1'bz;
  assign dq_sample = dq;

  ddr5_refresh_controller #(.TREFI(T_REFI1), .TRFC(T_RFC1)) u_refresh_controller (
    .ck(ck_t), .reset_n(reset_n),
    .enable(!self_refresh && !power_down),
    .refab_cmd(pair_valid && cmd_valid && (cmd == CMD_REFAB)),
    .refsb_cmd(pair_valid && cmd_valid && (cmd == CMD_REFSB)),
    .rfmab_cmd(pair_valid && cmd_valid && (cmd == CMD_RFMAB)),
    .rfmsb_cmd(pair_valid && cmd_valid && (cmd == CMD_RFMSB)),
    .ba(map_ba), .fgr_enable(fgr_en), .rfm_enable(rfm_en),
    .refresh_due(), .refresh_busy(), .refresh_row(),
    .same_bank_counter(), .refresh_error(refresh_error)
  );

  ddr5_init_fsm u_init_fsm (
    .ck(ck_t), .reset_n(reset_n),
    .zq_present(zq), .zq_complete(zq_done),
    .training_done(train_done), .init_done(init_done),
    .issue_mrw(), .issue_mpc(), .issue_zq(issue_zq), .issue_training(issue_training)
  );

  ddr5_training_controller u_training_controller (
    .ck(ck_t), .reset_n(reset_n), .start(issue_training),
    .read_training_en(rt_en), .write_leveling_en(wl_en),
    .ca_done(), .cs_done(), .wl_done(), .rd_done(), .vref_done(),
    .done(train_done), .training_error(train_error)
  );

  ddr5_mpc_controller u_mpc_controller (
    .ck(ck_t), .reset_n(reset_n),
    .valid(pair_valid && cmd_valid && (cmd == CMD_MPC)), .op(mpc_op),
    .zq_start(mpc_zq_start), .zq_latch(), .dll_reset(mpc_dll_reset),
    .enter_ca_training(), .enter_cs_training(), .exit_cs_training(),
    .set_2n(), .set_1n(), .manual_ecs(mpc_ecs),
    .dqs_osc_start(), .dqs_osc_stop(), .apply_vref_odt()
  );

  ddr5_power_controller u_power_controller (
    .ck(ck_t), .reset_n(reset_n),
    .sre(pair_valid && cmd_valid && (cmd == CMD_SRE)),
    .sref(pair_valid && cmd_valid && (cmd == CMD_SREF)),
    .srx(pair_valid && cmd_valid && (cmd == CMD_SRX)),
    .pde(pair_valid && cmd_valid && (cmd == CMD_PDE)),
    .pdx(pair_valid && cmd_valid && (cmd == CMD_PDX)),
    .self_refresh(self_refresh), .freq_change_mode(), .power_down(power_down)
  );

  ddr5_odt_vref_zq u_odt_vref_zq (
    .ck(ck_t), .reset_n(reset_n), .mr32(mr32), .mr33(mr33),
    .vrefca_code(vca), .vrefcs_code(vcs), .vrefdq_code(vdq),
    .vrefca_in(vrefca), .vrefdq_in(vrefdq),
    .zq_command(zq_trigger || mpc_zq_start),
    .odt_active(odt_active), .zq_done(zq_done), .vrefca(), .vrefcs(), .vrefdq()
  );

  ddr5_alert_controller u_alert_controller (
    .ck(ck_t), .reset_n(reset_n),
    .crc_error(1'b0),
    .ecc_error(timing_error || refresh_error || row_state_error),
    .training_error(train_error),
    .alert_n(alert_n)
  );


  always_ff @(posedge ck_t or negedge reset_n) begin
    if (!reset_n) begin
      mem_we        <= 1'b0;
      read_active   <= 1'b0;
      write_active  <= 1'b0;
      beat          <= '0;
      wr_beat       <= '0;
      read_delay    <= '0;
      write_delay   <= '0;
      wr_fifo_clear <= 1'b0;
      ap_active_q   <= 1'b0;
      ap_bank_q     <= '0;
    end else begin
      mem_we        <= 1'b0;
      wr_fifo_clear <= 1'b0;

      if (wr_fifo_clear) wr_beat <= '0;
      else if (phy_rx_valid) wr_beat <= wr_beat + 1'b1;

      if (pair_valid && cmd_valid && !self_refresh && !power_down && init_done) begin
        if ((cmd == CMD_RD || cmd == CMD_RDA) && legal_rd && active[bank_id]) begin

          read_active  <= 1'b1;
          write_active <= 1'b0;
          beat         <= '0;
          read_delay   <= CL[5:0];
          ap_active_q  <= ap;
          ap_bank_q    <= bank_id;
        end else if ((cmd == CMD_WR || cmd == CMD_WRA ||
                      cmd == CMD_WRP || cmd == CMD_WRPA) &&
                     legal_wr && active[bank_id]) begin

          write_active  <= 1'b1;
          read_active   <= 1'b0;
          beat          <= '0;
          write_delay   <= CWL[5:0];
          wr_fifo_clear <= 1'b1;
          ap_active_q   <= ap;
          ap_bank_q     <= bank_id;
        end
      end

      if (read_active) begin
        if (read_delay != 0) read_delay <= read_delay - 1'b1;
        else if (burst_done) read_active <= 1'b0;
        else beat <= beat + 1'b1;
      end

      if (write_active) begin
        if (write_delay != 0)      write_delay <= write_delay - 1'b1;
        else if (wr_fifo_valid) begin

          mem_we       <= 1'b1;
          write_active <= 1'b0;
        end else if (beat < 6'd15) begin
          beat <= beat + 1'b1;
        end
      end

    end
  end

  assign auto_precharge_event = burst_done && (read_active || write_active) && ap_active_q;
  assign auto_precharge_bank  = ap_bank_q;

endmodule

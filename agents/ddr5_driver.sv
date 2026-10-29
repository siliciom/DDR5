class ddr5_driver extends uvm_driver #(ddr5_seq_item);
 
`uvm_component_utils(ddr5_driver)
 
virtual ddr5_interface vif;

ddr5_seq_item seq;
 
int faw_count = 0;
 
int pending_write_data = 0;
 
// ---------------------------------------------------------

// DDR5 timing checker history (report-only)

// ---------------------------------------------------------
 
localparam int NUM_BG = (1 << `BG_WIDTH);

localparam int NUM_BA = (1 << `BA_WIDTH);
 
bit timing_history_valid = 1'b0;
 
// Last command cycle for each bank

longint unsigned last_act_cycle [NUM_BG][NUM_BA];

longint unsigned last_pre_cycle [NUM_BG][NUM_BA];

longint unsigned last_read_cycle[NUM_BG][NUM_BA];

longint unsigned last_write_cycle[NUM_BG][NUM_BA];
 
bit have_act [NUM_BG][NUM_BA];

bit have_pre [NUM_BG][NUM_BA];

bit have_read[NUM_BG][NUM_BA];

bit have_write[NUM_BG][NUM_BA];

bit bank_open [NUM_BG][NUM_BA];

// Last ACT command globally, for tRRD checking

longint unsigned last_any_act_cycle;

bit have_any_act = 1'b0;

bit [`BG_WIDTH-1:0] last_act_bg;

bit [`BA_WIDTH-1:0] last_act_ba;
 
// Keep recent ACT cycles for tFAW checking

longint unsigned act_history[4];

int act_history_count = 0;

int act_history_next  = 0;
 
// Reference-driver command timing / write-link state.

longint unsigned drv_ck_count = 0;

longint unsigned last_rw_cmd_cycle = 0;

bit have_last_rw = 0;

rand_cmd last_rw_cmd = NOP;

bit [`BG_WIDTH-1:0] last_rw_bg = '0;

bit last_write_bl16 = 0;

localparam int NEXT_CA2_EDGES = 2;

localparam int SEAMLESS_TCCD = 8;

int tccd_s_cfg = `TCCD_S;
 
typedef enum bit [1:0] { WR_NORMAL, WR_SEAMLESS, WR_INTERAMBLE } write_mode_e;

typedef struct packed { write_mode_e mode; int tccd; } write_link_t;

int write_id_counter = 0;

write_link_t write_link_by_id[int];
 
bit [7:0] mr_cfg [bit [7:0]];

bit [1:0] current_wr_preamble;

bit current_wr_postamble;
 
event preamble_done_ev;
 
function new(string name = "ddr5_driver", uvm_component parent = null);

super.new(name, parent);

endfunction
 
function void build_phase(uvm_phase phase);

super.build_phase(phase);
 
if (!uvm_config_db#(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif))

  `uvm_fatal("DRV", "NO INTERFACE")
 
void'(uvm_config_db#(int)::get(this, "", "tccd_s_cfg", tccd_s_cfg));

`uvm_info("DDR5_TCCD_CFG", $sformatf("Configured tCCD_S=%0d CK", tccd_s_cfg), UVM_LOW)
 
endfunction
 
task automatic clear_timing_history();
 
  for (int bg = 0; bg < NUM_BG; bg++) begin

    for (int ba = 0; ba < NUM_BA; ba++) begin

      bank_open[bg][ba] = 1'b0;

      have_act [bg][ba] = 1'b0;

      have_pre [bg][ba] = 1'b0;

      have_read[bg][ba] = 1'b0;

      have_write[bg][ba] = 1'b0;
 
      last_act_cycle [bg][ba] = 0;

      last_pre_cycle [bg][ba] = 0;

      last_read_cycle[bg][ba] = 0;

      last_write_cycle[bg][ba] = 0;

    end

  end
 
  have_any_act     = 1'b0;

  last_any_act_cycle = 0;

  act_history_count = 0;

  act_history_next  = 0;
 
  foreach (act_history[i])

    act_history[i] = 0;
 
  timing_history_valid = 1'b1;
 
endtask
 
task automatic check_timing_before_cmd(

  input rand_cmd              cmd,

  input bit [`BG_WIDTH-1:0]   bg,

  input bit [`BA_WIDTH-1:0]   ba

);
 
  longint unsigned now_cycle;

  longint unsigned elapsed;

  int required;
 
  now_cycle = drv_ck_count;
 
  if (!timing_history_valid)

    return;
 
  case (cmd)
 
    // -----------------------------------------------------

    // ACTIVATE timing checks

    // -----------------------------------------------------

    ACTIVATE: begin
 
      // tRP: PRECHARGE -> next ACTIVATE, same bank

      if (have_pre[bg][ba]) begin

        elapsed = now_cycle - last_pre_cycle[bg][ba];
 
        if (elapsed < `TRP)

          `uvm_warning("TIMING_TRP", $sformatf("tRP violation: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRP))

      end
 
      // tRC: ACTIVATE -> next ACTIVATE, same bank

      if (have_act[bg][ba]) begin

        elapsed = now_cycle - last_act_cycle[bg][ba];
 
        if (elapsed < `TRC)

          `uvm_warning("TIMING_TRC", $sformatf("tRC violation: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRC))

      end
 
      // tRRD_S / tRRD_L: consecutive ACTIVATE commands

      if (have_any_act) begin

        elapsed = now_cycle - last_any_act_cycle;
 
        if (bg == last_act_bg)

          required = `TRRD_L;

        else

          required = `TRRD_S;
 
        if (elapsed < required)

          `uvm_warning("TIMING_TRRD", $sformatf("tRRD violation: previous BG=%0d, current BG=%0d, elapsed=%0d required=%0d", last_act_bg, bg, elapsed, required))

      end
 
      // tFAW: an ACTIVATE must not violate the four-ACT window

      if (act_history_count >= 4) begin

        elapsed = now_cycle - act_history[act_history_next];
 
        if (elapsed < `TFAW)`uvm_warning("TIMING_TFAW", $sformatf("tFAW violation: elapsed=%0d required=%0d",elapsed, `TFAW))

      end
 
    

    end
 
    // -----------------------------------------------------

    // READ timing checks

    // -----------------------------------------------------

    READ, READ_AP: begin

            if (!bank_open[bg][ba]) begin

    `uvm_warning("TIMING_BANK_CLOSED", $sformatf("READ/WRITE to closed bank: BG=%0d BA=%0d", bg, ba))

end
 
      // tRCD: ACTIVATE -> READ, same bank

      if (have_act[bg][ba]) begin

        elapsed = now_cycle - last_act_cycle[bg][ba];
 
        if (elapsed < `TRCD)

          `uvm_warning("TIMING_TRCD", $sformatf("tRCD violation before READ: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRCD))

      end
 
      

    end
 
    // -----------------------------------------------------

    // WRITE timing checks

    // -----------------------------------------------------

    WRITE, WRITE_AP: begin

        if (!bank_open[bg][ba]) begin

    `uvm_warning("TIMING_BANK_CLOSED", $sformatf("READ/WRITE to closed bank: BG=%0d BA=%0d", bg, ba))

end
 
      // tRCD: ACTIVATE -> WRITE, same bank

      if (have_act[bg][ba]) begin

        elapsed = now_cycle - last_act_cycle[bg][ba];
 
        if (elapsed < `TRCD)`uvm_warning("TIMING_TRCD", $sformatf("tRCD violation before WRITE: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRCD))

      end
 
     

    end
 
    // -----------------------------------------------------

    // PRECHARGE timing checks

    // -----------------------------------------------------

    PRECHARGE, PRECHARGE_SB, PRECHARGE_ALL: begin
 
      // For PRECHARGE_ALL, the actual affected banks must

      // be checked individually; this branch checks only

      // the BG/BA passed to this task.

      if (bank_open[bg][ba]) begin

    elapsed = now_cycle - last_act_cycle[bg][ba];
 
    if (elapsed < `TRAS)

        `uvm_warning("TIMING_TRAS", $sformatf("tRAS violation before PRECHARGE: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRAS))

end

      // tRTP: READ -> PRECHARGE, same bank

      if (have_read[bg][ba]) begin

        elapsed = now_cycle - last_read_cycle[bg][ba];
 
        if (elapsed < `TRTP)

          `uvm_warning("TIMING_TRTP", $sformatf("tRTP violation before PRECHARGE: BG=%0d BA=%0d elapsed=%0d required=%0d", bg, ba, elapsed, `TRTP))

      end
 
      

    end
 
    default: begin

          end
 
  endcase
 
endtask
 
task automatic record_timing_after_cmd(

    input rand_cmd cmd,

    input bit [`BG_WIDTH-1:0] bg,

    input bit [`BA_WIDTH-1:0] ba

);

    longint unsigned issue_cycle;
 
    issue_cycle = drv_ck_count;
 
    case (cmd)
 
        ACTIVATE: begin

            bank_open[bg][ba] = 1'b1;

            have_read[bg][ba]  = 1'b0;

            have_write[bg][ba] = 1'b0;

            last_act_cycle[bg][ba] = issue_cycle;

            have_act[bg][ba]       = 1'b1;
 
            last_any_act_cycle = issue_cycle;

            last_act_bg        = bg;

            last_act_ba        = ba;

            have_any_act       = 1'b1;
 
            act_history[act_history_next] = issue_cycle;

            act_history_next = (act_history_next + 1) % 4;
 
            if (act_history_count < 4)

                act_history_count++;

        end
 
        READ, READ_AP: begin

            last_read_cycle[bg][ba] = issue_cycle;

            have_read[bg][ba]       = 1'b1;

        end
 
        WRITE, WRITE_AP: begin

            last_write_cycle[bg][ba] = issue_cycle;

            have_write[bg][ba]       = 1'b1;

        end
 
        PRECHARGE, PRECHARGE_SB: begin

            last_pre_cycle[bg][ba] = issue_cycle;

            bank_open[bg][ba] = 1'b0;

            have_pre[bg][ba]       = 1'b1;
 
             have_read[bg][ba]      = 1'b0;

              have_write[bg][ba]     = 1'b0;

        end
 
        default: begin

        end
 
    endcase

endtask
 
 
task run_phase(uvm_phase phase);

  fork

    begin : DRIVER_CK_COUNTER

      forever begin

        @(vif.ddr5_drv_cb_c);

        drv_ck_count++;

      end

    end

  join_none
 
  seq_item_port.get_next_item(seq);

  ddr5_initialize();

  drive_tx(seq);

  seq_item_port.item_done();
 
  forever begin

    seq_item_port.get_next_item(seq);

    drive_tx(seq);

    seq_item_port.item_done();

  end

endtask
 
// BUS INITIALIZATION

task bus_init();

  @(vif.ddr5_drv_cb_t);
 
  vif.ddr5_drv_cb_t.ca <= 'z;

  vif.ddr5_dq_drv_cb_t.dq <= 'z;
 
  vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b0;

  vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

  vif.ddr5_wr_drv_cb_t.dqsl_t <= 1'b0;

  vif.ddr5_wr_drv_cb_t.dqsl_c <= 1'b0;

  vif.ddr5_wr_drv_cb_t.dqsu_t <= 1'b0;

  vif.ddr5_wr_drv_cb_t.dqsu_c <= 1'b0;
 
   if (`DATA_WIDTH == 8) begin

    // x8 device: DML_n and DMU_n are unused

    vif.ddr5_dq_drv_cb_t.dml_n <= 1'b0;

    vif.ddr5_dq_drv_cb_t.dmu_n <= 1'b0;

    vif.ddr5_dq_drv_cb_t.dm_n  <= 1'b1;

end

else if (`DATA_WIDTH == 16) begin

    vif.ddr5_dq_drv_cb_t.dml_n <= 1'b1;

    vif.ddr5_dq_drv_cb_t.dmu_n <= 1'b1;

    vif.ddr5_dq_drv_cb_t.dm_n  <= 1'b0;

end

else begin

    vif.ddr5_dq_drv_cb_t.dm_n  <= 1'b0;

    vif.ddr5_dq_drv_cb_t.dml_n <= 1'b0;

    vif.ddr5_dq_drv_cb_t.dmu_n <= 1'b0;

end

endtask
 
// DDR5 INITIALIZATION
 
task ddr5_initialize();

  bus_init();

  reset_sequence();

  clear_timing_history();

// clear_driver_state_after_reset();

configure_mode_registers();

endtask
 
// RESET

task reset_sequence();

vif.ddr5_drv_cb_t.reset_n <= 1'b0;

vif.ddr5_drv_cb_t.cs_n    <= 1'b0;

vif.ddr5_drv_cb_t.ca      <= 'z;
 
repeat (`TINIT1)

  @(vif.ddr5_drv_cb_t);
 
vif.ddr5_drv_cb_t.reset_n <= 1'b1;
 
repeat (`TINIT3)

  @(vif.ddr5_drv_cb_t);
 
vif.ddr5_drv_cb_t.cs_n <= 1'b1;

vif.ddr5_drv_cb_t.ca   <= 'z;
 
repeat (`TINIT4)

  @(vif.ddr5_drv_cb_t);
 
vif.ddr5_drv_cb_t.ca <= 'z;
 
endtask
 
task clear_driver_state_after_reset();

  mr_cfg.delete();
 
  

  current_wr_preamble  = 2'b00;

  current_wr_postamble = 1'b0;

  mr_cfg[8'd8] = 8'h00;

  write_link_by_id.delete();

  have_last_rw = 1'b0;

  last_rw_cmd = NOP;

  last_rw_bg = '0;

  last_write_bl16 = 1'b0;
 
  `uvm_info("DDR5_DRV","Driver MR tracking reset to defaults; waiting for sequence MRWs",UVM_LOW)

endtask
 
 
// DDR5 RESET INITIALIZATION WITH STABLE POWER

task stable_power_reset();
 
  // Assert RESET_n and CS_n LOW.

  vif.ddr5_drv_cb_t.reset_n <= 1'b0;

  vif.ddr5_drv_cb_t.cs_n    <= 1'b0;

  vif.ddr5_drv_cb_t.ca      <= 'z;
 
  
 
  // Hold reset for the required tPW_RESET.

  repeat (`TPW_RESET)

    @(vif.ddr5_drv_cb_t);
 
  // Deassert RESET_n while CS_n remains LOW.

  vif.ddr5_drv_cb_t.reset_n <= 1'b1;
 
  // Wait the required post-reset initialization interval.

  repeat (`TINIT3)

    @(vif.ddr5_drv_cb_t);
 
  vif.ddr5_drv_cb_t.cs_n <= 1'b1;

  vif.ddr5_drv_cb_t.ca   <= 'z;
 
  repeat (`TINIT4)

    @(vif.ddr5_drv_cb_t);
 
  
 
  repeat (`TXPR)

    @(vif.ddr5_drv_cb_t);
 
  `uvm_info("DDR5_DRV", "Stable-power RESET timing sequence completed", UVM_LOW)
 
endtask
 
// MODE REGISTER CONFIGURATION
 
task configure_mode_registers();

mr_cfg[8'd0] = {1'b0, seq.rl, seq.bl};
 
if (`DATA_WIDTH == 4)

  mr_cfg[8'd5] = 8'h00;

else

  mr_cfg[8'd5] = {2'b00, seq.dm_cfg, 5'b00000};
 
mr_cfg[8'd6]  = {seq.trp_cfg, seq.wr_recovery};

mr_cfg[8'd8]  = {seq.wr_postamble, seq.rd_postamble, 1'b0, seq.wr_preamble, seq.rd_preamble};

mr_cfg[8'd50] = {7'b0000000, seq.crc_en};
 
foreach (mr_cfg[mra])

  mrw(mra, mr_cfg[mra]);
 
endtask
 
// DRIVE COMMAND
 
task drive_cmd(input bit cs, input bit [13:0] ca);

@(vif.ddr5_drv_cb_t);

vif.ddr5_drv_cb_t.cs_n <= cs;

vif.ddr5_drv_cb_t.ca   <= ca;

endtask
 
// RELEASE CA

task release_ca();

@(vif.ddr5_drv_cb_t);

vif.ddr5_drv_cb_t.ca   <= 'z;

vif.ddr5_drv_cb_t.cs_n <= 1'b1;

endtask
 
// NOP
 
task nop();

  bit [13:0] ca;
 
  ca = {9'b0, 5'b11111};
 
  drive_cmd(1'b0, ca);
 
  repeat (`TINIT5)

    @(vif.ddr5_drv_cb_t);
 
  @(vif.ddr5_drv_cb_t);

  vif.ddr5_drv_cb_t.ca   <= 'z;

  vif.ddr5_drv_cb_t.cs_n <= 1'b1;

endtask
 
// MODE REGISTER WRITE

task mrw(input bit [7:0] mra, input bit [7:0] mr_opcode);

  bit [13:0] ca1;

  bit [13:0] ca2;
 
  ca1 = {1'b0, mra, 5'b00101};

  ca2 = {6'b0, mr_opcode};
 
  `uvm_info("DDR5_MRW",

    $sformatf("Driving MRW: MRA=%0d OPCODE=0x%02h", mra, mr_opcode),

    UVM_LOW)
 
  drive_cmd(1'b0, ca1);

  drive_cmd(1'b1, ca2);

  release_ca();
 
  // Store the value issued on the bus.

  mr_cfg[mra] = mr_opcode;
 
  // Update write preamble/postamble tracking only when MR8 is written.

  if (mra == 8'd8) begin

    current_wr_preamble  = mr_opcode[4:3];

    current_wr_postamble = mr_opcode[7];

    `uvm_info("DDR5_DRV", $sformatf("MR8 UPDATED: OPCODE=0x%02h WR_PRE=%0b WR_POST=%0b", mr_opcode, current_wr_preamble, current_wr_postamble), UVM_LOW)

  end
 
  repeat (`TMRD)

    @(vif.ddr5_drv_cb_t);

endtask
 
// MODE REGISTER READ

task mrr(ddr5_seq_item seq);

bit [13:0] ca1;

bit [13:0] ca2;
 
ca1 = {1'b0, seq.mra, 5'b10101};

ca2 = '0;
 
drive_cmd(1'b0, ca1);

drive_cmd(1'b1, ca2);

release_ca();
 
endtask
 
// ACTIVATE

task activate(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    longint unsigned elapsed;

    longint unsigned remaining;
 
    ca1 = {3'b000, seq.bg, seq.ba, seq.row[3:0], 2'b00};

    ca2 = seq.row[17:4];
 
    // Wait for tRP after PRECHARGE to this bank.

    if (have_pre[seq.bg][seq.ba]) begin

        elapsed = drv_ck_count - last_pre_cycle[seq.bg][seq.ba];
 
        if (elapsed < `TRP) begin

            remaining = `TRP - elapsed;
 
            `uvm_info("DDR5_TRP_WAIT", $sformatf( "BG=%0d BA=%0d elapsed=%0d required=%0d waiting=%0d CK", seq.bg, seq.ba, elapsed, `TRP, remaining), UVM_LOW)
 
            repeat (remaining)

                @(vif.ddr5_drv_cb_t);

        end

    end
 
    check_timing_before_cmd(ACTIVATE, seq.bg, seq.ba);
 
    `uvm_info("DDR5_DRV", $sformatf("DRIVING ACTIVATE BG=%0d BA=%0d ROW=%0d", seq.bg, seq.ba, seq.row), UVM_LOW)
 
    drive_cmd(1'b0, ca1);

    record_timing_after_cmd(ACTIVATE, seq.bg, seq.ba);
 
    drive_cmd(1'b1, ca2);

    release_ca();

endtask

// DQS - ONE CLOCK ZERO

task drive_1ck_zero();
 
  @(vif.ddr5_drv_cb_t);
 
  if (`DATA_WIDTH == 16) begin

    vif.ddr5_wr_drv_cb_t.dqsl_t <= 1'b0;

    vif.ddr5_wr_drv_cb_t.dqsl_c <= 1'b1;

    vif.ddr5_wr_drv_cb_t.dqsu_t <= 1'b0;

    vif.ddr5_wr_drv_cb_t.dqsu_c <= 1'b1;

  end

  else begin

    vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b0;

    vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b1;

  end
 
  @(vif.ddr5_drv_cb_c);
 
  if (`DATA_WIDTH == 16) begin

    vif.ddr5_wr_drv_cb_c.dqsl_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqsl_c <= 1'b1;

    vif.ddr5_wr_drv_cb_c.dqsu_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqsu_c <= 1'b1;

  end

  else begin

    vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

  end
 
endtask
 
 
// DQS - ONE CLOCK ONE/ZERO
 
task drive_1ck_onezero();
 
  @(vif.ddr5_drv_cb_t);
 
  if (`DATA_WIDTH == 16) begin

    vif.ddr5_wr_drv_cb_t.dqsl_t <= 1'b1;

    vif.ddr5_wr_drv_cb_t.dqsl_c <= 1'b0;

    vif.ddr5_wr_drv_cb_t.dqsu_t <= 1'b1;

    vif.ddr5_wr_drv_cb_t.dqsu_c <= 1'b0;

  end

  else begin

    vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b1;

    vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

  end
 
  @(vif.ddr5_drv_cb_c);
 
  if (`DATA_WIDTH == 16) begin

    vif.ddr5_wr_drv_cb_c.dqsl_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqsl_c <= 1'b1;

    vif.ddr5_wr_drv_cb_c.dqsu_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqsu_c <= 1'b1;

  end

  else begin

    vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0;

    vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

  end
 
endtask

  // Write Preamble

  task drive_write_preamble(bit [1:0] wr_preamble);

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] WRITE PREAMBLE START WR_PRE=%0d",$time,wr_preamble),UVM_LOW)

    case (wr_preamble)

      // 2 tCK  : 0010

      WR_PRE_2TCK: begin

        repeat (`TCWL - 3) @(vif.ddr5_drv_cb_t);

        // 0010 pattern

        drive_1ck_zero();

        drive_1ck_onezero();

      end

      // 3 tCK  : 000010

      WR_PRE_3TCK: begin

        repeat (`TCWL - 4)@(vif.ddr5_drv_cb_t);

        // 000010 pattern

        repeat (2)

          drive_1ck_zero();

        drive_1ck_onezero();

      end

      // 4 tCK : 00001010

      WR_PRE_4TCK: begin

        repeat (`TCWL - 5)@(vif.ddr5_drv_cb_t);

        repeat (2)

          drive_1ck_zero();

        repeat (2)

          drive_1ck_onezero();

      end

      default: begin

        repeat (`TCWL - 3)

          @(vif.ddr5_drv_cb_t);

        // Default 2 tCK preamble : 0010

        drive_1ck_zero();

        drive_1ck_onezero();

      end

    endcase

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] WRITE PREAMBLE END",$time),UVM_LOW)


    -> preamble_done_ev;

  endtask
 
  // Classify consecutive BL16 writes using the observed command spacing.

  function automatic write_mode_e classify_write(

    input ddr5_seq_item wr_seq, input int actual_tccd);

    if (!have_last_rw || last_rw_cmd != WRITE || !last_write_bl16 ||

        wr_seq.bl != BL16 || last_rw_bg == wr_seq.bg)

      return WR_NORMAL;

    if (actual_tccd == SEAMLESS_TCCD) return WR_SEAMLESS;

    if (actual_tccd >= 9 && actual_tccd <= 13) return WR_INTERAMBLE;

    return WR_NORMAL;

  endfunction
 
  function automatic int get_wr_preamble_ck(input bit [1:0] wr_pre);

    case (wr_pre)

      WR_PRE_2TCK: return 2;

      WR_PRE_3TCK: return 3;

      WR_PRE_4TCK: return 4;

      default: return 2;

    endcase

  endfunction
 
  // Reference overlap table for a new write's preamble at tCCD=9..13.

  function automatic int get_interamble_skip_ck(

    input bit [1:0] wr_pre, input bit wr_post, input int tccd);

    if (tccd < 9 || tccd > 13) return 0;

    case (tccd)

      9: return 0;

      10: begin

        if (wr_post == WR_PSTBLE_0_5TCK) begin

          case (wr_pre)

            WR_PRE_2TCK: return 0;

            WR_PRE_3TCK: return 1;

            WR_PRE_4TCK: return 2;

            default: return 0;

          endcase

        end

        case (wr_pre)

          WR_PRE_2TCK: return 1;

          WR_PRE_3TCK: return 2;

          WR_PRE_4TCK: return 2;

          default: return 0;

        endcase

      end

      11: begin

        if (wr_post == WR_PSTBLE_0_5TCK) begin

          case (wr_pre)

            WR_PRE_2TCK, WR_PRE_3TCK: return 0;

            WR_PRE_4TCK: return 1;

            default: return 0;

          endcase

        end

        case (wr_pre)

          WR_PRE_2TCK: return 0;

          WR_PRE_3TCK: return 1;

          WR_PRE_4TCK: return 2;

          default: return 0;

        endcase

      end

      12: begin

        if (wr_post == WR_PSTBLE_0_5TCK) return 0;

        if (wr_pre == WR_PRE_4TCK) return 1;

        return 0;

      end

      13: return 0;

      default: return 0;

    endcase

  endfunction
 
  task drive_write_interamble_preamble( input bit [1:0] wr_pre, input bit wr_post, input int tccd);
 
    int pre_ck, skip_ck, remaining_ck;
 
    pre_ck = get_wr_preamble_ck(wr_pre);

    skip_ck = get_interamble_skip_ck(wr_pre, wr_post, tccd);

    remaining_ck = pre_ck - skip_ck;
 
    `uvm_info("DDR5_DRV_TIMING", $sformatf("INTERAMBLE PRE=%0d POST=%0b TCCD=%0d SKIP=%0d", pre_ck, wr_post, tccd, skip_ck), UVM_LOW)
 
    if (remaining_ck <= 0) return;

    repeat (`TCWL - remaining_ck - 1) @(vif.ddr5_drv_cb_t);

    for (int ck = skip_ck; ck < pre_ck; ck++) begin

      if ((ck == pre_ck-1) || ((wr_pre == WR_PRE_4TCK) && ck >= 2))

        drive_1ck_onezero();

      else

        drive_1ck_zero();

    end

  endtask
 
  function automatic int get_write_write_tccd(

    input bit [`BG_WIDTH-1:0] prev_bg, input bit [`BG_WIDTH-1:0] next_bg);

    return (prev_bg != next_bg) ? tccd_s_cfg : `TCCD_L_WR;

  endfunction
 
  function automatic int get_read_read_tccd(

    input bit [`BG_WIDTH-1:0] prev_bg, input bit [`BG_WIDTH-1:0] next_bg);

    return (prev_bg == next_bg) ? `TCCD_L : `TCCD_S;

  endfunction
 
  function automatic int get_write_read_timing(

    input bit [`BG_WIDTH-1:0] prev_bg, input bit [`BG_WIDTH-1:0] next_bg);

    return (prev_bg == next_bg) ? (`TCWL + 8 + `TWTR_L) : (`TCWL + 8 + `TWTR_S);

  endfunction
 
 
task wait_rw_transition(

    input rand_cmd next_cmd,

    input bit [`BG_WIDTH-1:0] next_bg

);

    int required;

    int remaining;

    int elapsed;
 
    if (!have_last_rw)

        return;
 
    required = 0;
 
    // WRITE / WRITE_AP -> WRITE / WRITE_AP

    if (last_rw_cmd == WRITE && (next_cmd == WRITE || next_cmd == WRITE_AP)) begin
 
        required = get_write_write_tccd(last_rw_bg, next_bg);

    end
 
    // READ / READ_AP -> READ / READ_AP

    else if (last_rw_cmd == READ && (next_cmd == READ || next_cmd == READ_AP)) begin
 
        required = get_read_read_tccd(last_rw_bg, next_bg);

    end
 
    // WRITE / WRITE_AP -> READ / READ_AP

    else if (last_rw_cmd == WRITE && (next_cmd == READ || next_cmd == READ_AP)) begin
 
        required = get_write_read_timing(last_rw_bg, next_bg);

    end
 
    // READ / READ_AP -> WRITE / WRITE_AP

    else if (last_rw_cmd == READ && (next_cmd == WRITE || next_cmd == WRITE_AP)) begin
 
        `uvm_warning("DDR5_RTW","READ-to-WRITE turnaround timing is not configured")

    end
 
    if (required > 0) begin
 
        elapsed = int'(drv_ck_count - last_rw_cmd_cycle) + NEXT_CA2_EDGES;

 
        remaining = required - elapsed;
 
        if (remaining > 0) begin

            `uvm_info("DDR5_CMD_TIMING", $sformatf( "PREV_CMD=%0d PREV_BG=%0d NEXT_CMD=%0d NEXT_BG=%0d REQUIRED=%0d ELAPSED=%0d WAIT=%0d", last_rw_cmd, last_rw_bg, next_cmd, next_bg, required, elapsed,remaining ), UVM_MEDIUM)
 
            repeat (remaining)

                @(vif.ddr5_drv_cb_t);

        end

    end

endtask

  task drive_write_postamble(input bit wr_post, input bit release_dqs = 1'b1);

    @(vif.ddr5_drv_cb_t);

    if (`DATA_WIDTH == 16) begin

      vif.ddr5_wr_drv_cb_t.dqsl_t <= 1'b0; vif.ddr5_wr_drv_cb_t.dqsl_c <= 1'b1;

      vif.ddr5_wr_drv_cb_t.dqsu_t <= 1'b0; vif.ddr5_wr_drv_cb_t.dqsu_c <= 1'b1;

    end else begin

      vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b0; vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b1;

    end

    @(vif.ddr5_drv_cb_c);

    if (wr_post == WR_PSTBLE_1_5TCK) begin

      @(vif.ddr5_drv_cb_t);

      @(vif.ddr5_drv_cb_c);

    end

    if (release_dqs) begin

      vif.ddr5_dq_drv_cb_t.dq <= 'z;

      vif.ddr5_dq_drv_cb_c.dq <= 'z;

      vif.ddr5_wr_drv_cb_t.dqs_t <= 'z; vif.ddr5_wr_drv_cb_t.dqs_c <= 'z;

      vif.ddr5_wr_drv_cb_c.dqs_t <= 'z; vif.ddr5_wr_drv_cb_c.dqs_c <= 'z;

      if (`DATA_WIDTH == 16) begin

        vif.ddr5_wr_drv_cb_t.dqsl_t <= 'z; vif.ddr5_wr_drv_cb_t.dqsl_c <= 'z;

        vif.ddr5_wr_drv_cb_c.dqsl_t <= 'z; vif.ddr5_wr_drv_cb_c.dqsl_c <= 'z;

        vif.ddr5_wr_drv_cb_t.dqsu_t <= 'z; vif.ddr5_wr_drv_cb_t.dqsu_c <= 'z;

        vif.ddr5_wr_drv_cb_c.dqsu_t <= 'z; vif.ddr5_wr_drv_cb_c.dqsu_c <= 'z;

      end

    end

  endtask
 
 
// COMMON WRITE DATA
 
task drive_write_data(ddr5_seq_item wr_seq, input bit [1:0] wr_pre,input bit wr_post,input int tccd,input write_mode_e mode, input int my_write_id);
 
  bit next_is_seamless_local;

  int next_write_id;

  write_mode_e next_mode;

  int next_tccd;
 
  fork
 
    begin : PREAMBLE_THREAD

      if (mode == WR_SEAMLESS) begin

        // Consecutive BL16 writes at tCCD=8 share the DQS burst.

      end else if (mode == WR_INTERAMBLE) begin

        drive_write_interamble_preamble(wr_pre, wr_post, tccd);

      end else begin

        drive_write_preamble(wr_pre);

      end

    end
 
    begin : DQ_THREAD

      bit bc8_upper_half;
      bit bl32_upper_half;
      int disp_indx;
      int burst_limit;

      repeat (`TCWL-2) @(vif.ddr5_drv_cb_t);

      bc8_upper_half  = (wr_seq.bl == BC8_OTF) && (wr_seq.col[3]);

      bl32_upper_half = (wr_seq.bl == BL32_OTF) &&
                        (wr_seq.ca5) &&
                        (wr_seq.col[10]);

      if ((wr_seq.bl == BC8_OTF) && (wr_seq.ca5 == 1'b0))
        burst_limit = 8;
      else
        burst_limit = 16;

      for (int i=0; i<burst_limit; i++) begin

        if ((i % 2) == 0) begin

          @(vif.ddr5_dq_drv_cb_t);

          if (bc8_upper_half)            
            vif.ddr5_dq_drv_cb_t.dq <= wr_seq.dq_burst[i+8];

          else if (bl32_upper_half)
            vif.ddr5_dq_drv_cb_t.dq <= wr_seq.dq_burst[i+16];

          else
            vif.ddr5_dq_drv_cb_t.dq <= wr_seq.dq_burst[i];

          if (`DATA_WIDTH == 16) begin

            vif.ddr5_dq_drv_cb_t.dml_n <= wr_seq.dml_burst[i];

            vif.ddr5_dq_drv_cb_t.dmu_n <= wr_seq.dmu_burst[i];

          end else if (`DATA_WIDTH == 8) begin

            vif.ddr5_dq_drv_cb_t.dm_n <= wr_seq.dm_burst[i];

          end

        end else begin

          @(vif.ddr5_dq_drv_cb_c);

          if (bc8_upper_half)
            vif.ddr5_dq_drv_cb_c.dq <= wr_seq.dq_burst[i+8];

          else if (bl32_upper_half)
            vif.ddr5_dq_drv_cb_c.dq <= wr_seq.dq_burst[i+16];

          else
            vif.ddr5_dq_drv_cb_c.dq <= wr_seq.dq_burst[i];

          if (`DATA_WIDTH == 16) begin

            vif.ddr5_dq_drv_cb_c.dml_n <= wr_seq.dml_burst[i];

            vif.ddr5_dq_drv_cb_c.dmu_n <= wr_seq.dmu_burst[i];

          end else if (`DATA_WIDTH == 8) begin

            vif.ddr5_dq_drv_cb_c.dm_n <= wr_seq.dm_burst[i];

          end

        end

        disp_indx = i;

        if (bc8_upper_half)
          disp_indx = i + 8;
        else if (bl32_upper_half)
          disp_indx = i + 16;

        `uvm_info("DRV_DQ",
          $sformatf("DRV_DQ[%0d] = %0h",
            disp_indx,
            bc8_upper_half  ? wr_seq.dq_burst[i+8]  :
            bl32_upper_half ? wr_seq.dq_burst[i+16] :
                              wr_seq.dq_burst[i]),
           UVM_LOW)

      end
 
      next_is_seamless_local = 1'b0;

      if (write_link_by_id.exists(my_write_id+1))

        next_is_seamless_local = (write_link_by_id[my_write_id+1].mode == WR_SEAMLESS);

      if (!next_is_seamless_local) begin

        @(vif.ddr5_dq_drv_cb_t);

        vif.ddr5_dq_drv_cb_t.dq <= 'z;

        vif.ddr5_dq_drv_cb_c.dq <= 'z;

      end

    end
 
   begin : DQS_THREAD

      int burst_limit;

      if ((wr_seq.bl == BC8_OTF) && (wr_seq.ca5 == 1'b0))
        burst_limit = 8;
      else
        burst_limit = 16;

      repeat (`TCWL-1) @(vif.ddr5_drv_cb_t);

      for (int i=0; i<burst_limit; i++) begin
        
        if ((i % 2) == 0) begin

          @(vif.ddr5_wr_drv_cb_t);

          if (`DATA_WIDTH == 16) begin

            vif.ddr5_wr_drv_cb_t.dqsl_t <= 1'b1; vif.ddr5_wr_drv_cb_t.dqsl_c <= 1'b0;

            vif.ddr5_wr_drv_cb_t.dqsu_t <= 1'b1; vif.ddr5_wr_drv_cb_t.dqsu_c <= 1'b0;

          end else begin

            vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b1; vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

          end

        end else begin

          @(vif.ddr5_wr_drv_cb_c);

          if (`DATA_WIDTH == 16) begin

            vif.ddr5_wr_drv_cb_c.dqsl_t <= 1'b0; vif.ddr5_wr_drv_cb_c.dqsl_c <= 1'b1;

            vif.ddr5_wr_drv_cb_c.dqsu_t <= 1'b0; vif.ddr5_wr_drv_cb_c.dqsu_c <= 1'b1;

          end else begin

            vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0; vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

          end

        end

      end

    end
 
  join
 
  next_write_id = my_write_id + 1;

  next_mode = WR_NORMAL;

  next_tccd = 0;

  if (write_link_by_id.exists(next_write_id)) begin

    next_mode = write_link_by_id[next_write_id].mode;

    next_tccd = write_link_by_id[next_write_id].tccd;

  end
 
  if (next_mode != WR_SEAMLESS)

    drive_write_postamble(wr_post, next_mode == WR_NORMAL);

  else

    `uvm_info("DDR5_DRV", $sformatf("WRITE[%0d] -> WRITE[%0d] SEAMLESS TCCD=%0d", my_write_id, next_write_id, next_tccd), UVM_LOW)
 
  if (next_mode == WR_INTERAMBLE)

    `uvm_info("DDR5_DRV", $sformatf("WRITE[%0d] -> WRITE[%0d] INTERAMBLE TCCD=%0d", my_write_id, next_write_id, next_tccd), UVM_LOW)
 
  write_link_by_id.delete(my_write_id);

endtask

// WRITE DATA BL32

task drive_write_data_bl32(ddr5_seq_item wr_seq, input bit [1:0] wr_pre, input bit wr_post);

  fork

  //--------------------------------------------------
  // PREAMBLE
  //--------------------------------------------------
   begin : PREAMBLE_THREAD

    case(wr_pre)

      WR_PRE_2TCK: begin
        repeat(`TCWL-12)
          @(vif.ddr5_drv_cb_t);

        drive_1ck_zero();
        drive_1ck_onezero();
      end

      WR_PRE_3TCK: begin
        repeat(`TCWL-13)
          @(vif.ddr5_drv_cb_t);

        repeat(2)
          drive_1ck_zero();

        drive_1ck_onezero();
      end

      WR_PRE_4TCK: begin
        repeat(`TCWL-14)
          @(vif.ddr5_drv_cb_t);

        repeat(2)
          drive_1ck_zero();

        repeat(2)
          drive_1ck_onezero();
      end

      default: begin
        repeat(`TCWL-12)
          @(vif.ddr5_drv_cb_t);

        drive_1ck_zero();
        drive_1ck_onezero();
      end

    endcase

  end

  //--------------------------------------------------
  // DQ
  //--------------------------------------------------
  begin : DQ_THREAD

    repeat(`TCWL-11)
      @(vif.ddr5_drv_cb_t);

    for(int i=0;i<32;i++) begin

      if((i%2)==0) begin

        @(vif.ddr5_dq_drv_cb_t);

        vif.ddr5_dq_drv_cb_t.dq <= wr_seq.dq_burst[i];

        `uvm_info("BL32_DRV_DQ", $sformatf("DQ[%0d]=%0d", i, wr_seq.dq_burst[i]), UVM_LOW)

      end
      else begin

        @(vif.ddr5_dq_drv_cb_c);

        vif.ddr5_dq_drv_cb_c.dq <= wr_seq.dq_burst[i];

        `uvm_info("BL32_DRV_DQ", $sformatf("DQ[%0d]=%0d", i, wr_seq.dq_burst[i]), UVM_LOW)

      end

      `uvm_info("BL32_DATA",
        $sformatf("DQ[%0d]=%0d",
                  i,
                  wr_seq.dq_burst[i]),
        UVM_LOW)

    end

    @(vif.ddr5_dq_drv_cb_t);

    vif.ddr5_dq_drv_cb_t.dq <= 'z;
    vif.ddr5_dq_drv_cb_c.dq <= 'z;

  end

  //--------------------------------------------------
  // DQS
  //--------------------------------------------------
  begin : DQS_THREAD

    repeat(`TCWL-10)
      @(vif.ddr5_drv_cb_t);

    for(int i=0;i<32;i++) begin

      if((i%2)==0) begin

        @(vif.ddr5_wr_drv_cb_t);

        vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b1;
        vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

      end
      else begin

        @(vif.ddr5_wr_drv_cb_c);

        vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0;
        vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

      end

    end

  end

join

drive_write_postamble(wr_post);

endtask

// COMMON WRITE
 
task write(ddr5_seq_item seq);

  bit [13:0] ca1, ca2;

  bit cmd_bl;

  bit [1:0] wr_pre;

  bit wr_post;

  write_mode_e mode;

  int tccd, my_write_id;

  longint unsigned this_write_cmd_cycle;

  ddr5_seq_item wr_seq;
 
  if ((seq.bl == BC8_OTF) || (seq.bl == BL32_OTF))
    cmd_bl = seq.ca5;
  else
    cmd_bl = 1'b1;

  ca1 = {3'b000, seq.bg, seq.ba, cmd_bl, 5'b01101};

  if (`DATA_WIDTH == 4)

    ca2 = {3'b000, seq.ap_n, 1'b0, seq.col[10:3], 1'b0};

  else

    ca2 = {3'b000, seq.ap_n, 1'b0, 1'b0, seq.col[9:3], 1'b0};
 
check_timing_before_cmd(seq.cmd, seq.bg, seq.ba);
 
drive_cmd(1'b0, ca1);

record_timing_after_cmd(seq.cmd, seq.bg, seq.ba);
 
drive_cmd(1'b1, ca2);

this_write_cmd_cycle = drv_ck_count;

release_ca();
 
  wr_seq = ddr5_seq_item::type_id::create($sformatf("wr_seq_%0d", write_id_counter));

  wr_seq.bl  = seq.bl;
  wr_seq.ca5 = seq.ca5;
  wr_seq.col = seq.col;

  for (int i=0; i<32; i++) begin

    wr_seq.dq_burst[i] = seq.dq_burst[i];

    if (`DATA_WIDTH == 16) begin

      wr_seq.dml_burst[i] = seq.dml_burst[i];

      wr_seq.dmu_burst[i] = seq.dmu_burst[i];

    end else if (`DATA_WIDTH == 8) begin

      wr_seq.dm_burst[i] = seq.dm_burst[i];

    end

  end
 
  wr_pre = current_wr_preamble;

  wr_post = current_wr_postamble;

  if (have_last_rw && last_rw_cmd == WRITE)

    tccd = int'(this_write_cmd_cycle - last_rw_cmd_cycle);

  else

    tccd = 0;

  mode = classify_write(seq, tccd);

  last_rw_cmd_cycle = this_write_cmd_cycle;

  my_write_id = write_id_counter++;

  write_link_by_id[my_write_id] = '{mode:mode, tccd:tccd};
 
  `uvm_info("DDR5_DRV", $sformatf("WRITE[%0d] CMD BG=%0d BA=%0d COL=%0d TCCD=%0d MODE=%s", my_write_id, seq.bg, seq.ba, seq.col, tccd, mode.name()), UVM_LOW)

  pending_write_data++;
 
  

fork

    begin : WRITE_DATA_BG

        drive_write_data( wr_seq, wr_pre, wr_post, tccd, mode, my_write_id);
 
        pending_write_data--;
 
        `uvm_info("DDR5_DRV", $sformatf( "WRITE[%0d] completed; pending=%0d",  my_write_id, pending_write_data),UVM_LOW )

    end

join_none
  
endtask

task write_bl32(ddr5_seq_item seq);

  bit [13:0] ca1, ca2;

  ca1 = {3'b000, seq.bg, seq.ba, 1'b0, 5'b01101};

  if (`DATA_WIDTH == 4)
    ca2 = {3'b000, 1'b1, 1'b0, seq.col[10:3], 1'b0};
  else
    ca2 = {3'b000, 1'b1, 1'b0, 1'b0, seq.col[9:3], 1'b0};

  check_timing_before_cmd(seq.cmd, seq.bg, seq.ba);

  drive_cmd(1'b0, ca1);

  record_timing_after_cmd(seq.cmd, seq.bg, seq.ba);

  drive_cmd(1'b1, ca2);

  release_ca();

  //----------------------------------
  // FIRST BL32 WRITE
  //----------------------------------

  if(seq.bl32_second_write == 1'b0) begin

      repeat(`BL32_OTF_CMD - 3)
         @(vif.ddr5_drv_cb_t);

  end

  //----------------------------------
  // SECOND BL32 WRITE
  //----------------------------------

  else begin

      drive_write_data_bl32(
         seq,
         current_wr_preamble,
         current_wr_postamble);

  end

endtask

task write_bl32_otf(ddr5_seq_item seq);

  //--------------------------------
  // CA5=0 => BL32
  //--------------------------------

  if(seq.ca5 == 1'b0) begin

      write_bl32(seq);

  end

  //--------------------------------
  // CA5=1 => BL16
  //--------------------------------

  else begin

      write(seq);

  end

endtask 
 
// COMMON READ COMMAND
 
task read(ddr5_seq_item seq);

bit [13:0] ca1;

bit [13:0] ca2;

bit cmd_bl;
 
if ((seq.bl == BC8_OTF) || (seq.bl == BL32_OTF))
  cmd_bl = seq.ca5;
else
  cmd_bl = 1'b1;
 
ca1 = {3'b000, seq.bg, seq.ba, cmd_bl, 5'b11101};
 
if (`DATA_WIDTH == 4)

  ca2 = {3'b000, seq.ap_n, 1'b0, seq.col[10:3], 1'b0};

else

  ca2 = {3'b000, seq.ap_n, 1'b0, 1'b0, seq.col[9:3], 1'b0};
 
check_timing_before_cmd(seq.cmd, seq.bg, seq.ba);
 
drive_cmd(1'b0, ca1);

record_timing_after_cmd(seq.cmd, seq.bg, seq.ba);
 
drive_cmd(1'b1, ca2);

last_rw_cmd_cycle = drv_ck_count;

release_ca();
 
repeat (seq.rl)

  @(vif.ddr5_drv_cb_t);
 
endtask
 
 
task precharge(ddr5_seq_item seq);

  bit [13:0] ca;

  longint unsigned elapsed;

  longint unsigned remaining;
 
 
      ca = {1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0,

      seq.ba, seq.bg, 3'b000};
 
  `uvm_info("DDR5_DRV", $sformatf("PRECHARGE | BG=%0d BA=%0d", seq.bg, seq.ba), UVM_LOW)
 
  // Wait for tRTP after READ to the same bank.

  if (have_read[seq.bg][seq.ba]) begin

    elapsed = drv_ck_count - last_read_cycle[seq.bg][seq.ba];
 
    if (elapsed < `TRTP) begin

      remaining = `TRTP - elapsed;
 
      `uvm_info("DDR5_TRTP_WAIT", $sformatf("BG=%0d BA=%0d elapsed=%0d required=%0d waiting=%0d CK", seq.bg, seq.ba, elapsed, `TRTP, remaining), UVM_LOW)
 
      repeat (remaining)

        @(vif.ddr5_drv_cb_t);

    end

  end
 
  // Check the timing again at the command issue point.

  check_timing_before_cmd(PRECHARGE, seq.bg, seq.ba);
 
  drive_cmd(1'b0, ca);

  record_timing_after_cmd(PRECHARGE, seq.bg, seq.ba);
 
  release_ca();

endtask
 
 
// PRECHARGE SAME BANK
 
task precharge_sb(ddr5_seq_item seq);

bit [13:0] ca;
 
ca = {1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0,seq.ba[0], seq.ba[1], 1'b0, 1'b0, 1'b0, 3'b000};
 
`uvm_info("DDR5_DRV", $sformatf("PRECHARGE SAME BANK | BA=%0d", seq.ba), UVM_LOW)
 
check_timing_before_cmd(PRECHARGE_SB, seq.bg, seq.ba);
 
drive_cmd(1'b0, ca);

record_timing_after_cmd(PRECHARGE_SB, seq.bg, seq.ba);
 
release_ca();
 
endtask
 
task automatic record_precharge_all();

    longint unsigned issue_cycle;

    issue_cycle = drv_ck_count;
 
    for (int bg = 0; bg < NUM_BG; bg++) begin

        for (int ba = 0; ba < NUM_BA; ba++) begin

            last_pre_cycle[bg][ba] = issue_cycle;

            bank_open[bg][ba] = 1'b0;            

            have_pre[bg][ba]       = 1'b1;

             have_read[bg][ba]      = 1'b0;

             have_write[bg][ba]     = 1'b0;

        end

    end

endtask
 
 
// PRECHARGE ALL
 
task precharge_all();

bit [13:0] ca;
 
ca = {1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0,

      8'b0};
 
`uvm_info("DDR5_DRV", "PRECHARGE ALL", UVM_LOW)
 
check_precharge_all_timing();

drive_cmd(1'b0, ca);

record_precharge_all();
 
release_ca();

endtask
 
task automatic check_precharge_all_timing();
 
    for (int bg = 0; bg < NUM_BG; bg++) begin

        for (int ba = 0; ba < NUM_BA; ba++) begin

            check_timing_before_cmd(PRECHARGE, bg, ba);

        end

    end
 
endtask

// POWER DOWN ENTRY
 
task powerdown_entry();

bit [13:0] ca;
 
ca = {1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0,

      4'b0, 1'b1, 1'b0, 2'b0};
 
`uvm_info("DDR5_DRV", "POWER DOWN ENTRY", UVM_LOW)
 
drive_cmd(1'b0, ca);

release_ca();
 
endtask
 
// POWER DOWN EXIT
 
task powerdown_exit();

bit [13:0] ca;
 
ca = {6'b111111, 8'b0};
 
`uvm_info("DDR5_DRV", "POWER DOWN EXIT", UVM_LOW)
 
drive_cmd(1'b0, ca);

release_ca();
 
endtask
 
// DRIVE TRANSACTION
 
task drive_tx(ddr5_seq_item seq);
 
  if (seq.reset_n == 1'b0) begin
 
    `uvm_info("DDR5_RESET", $sformatf("Waiting for pending write-data tasks: %0d", pending_write_data),UVM_LOW )
 
    // Allow every outstanding write to finish before asserting RESET_n.

    while (pending_write_data > 0)

        @(vif.ddr5_drv_cb_t);
 
    // Allow the monitor/scoreboard to process the final write transaction.

     @(vif.ddr5_drv_cb_t);
 
    vif.ddr5_drv_cb_t.cmd <= NOP;

    clear_timing_history();
 
    stable_power_reset();
 
    clear_driver_state_after_reset();
 
    have_last_rw = 1'b0;

    last_rw_cmd = NOP;

    last_rw_cmd_cycle = drv_ck_count;
 
    configure_mode_registers();

    return;

end
 
  `uvm_info("DRV", $sformatf("Received CMD=%0d BG=%0d BA=%0d COL=%0d", seq.cmd, seq.bg, seq.ba, seq.col), UVM_LOW)
 
  wait_rw_transition(seq.cmd, seq.bg);
 
    vif.ddr5_drv_cb_t.cmd <= seq.cmd;
 
  case (seq.cmd)

    ACTIVATE: begin

      if (seq.faw_test) begin

        faw_count++;

        if (faw_count == 1)

            activate(seq);

        else if

            (faw_count < 5) begin

                repeat(`FAW_RRD_GAP) @(vif.ddr5_drv_cb_t); activate(seq); end

        else begin

            repeat(`FAW_VIOLATION_GAP)

                @(vif.ddr5_drv_cb_t); activate(seq); end

        if ((seq.faw_test == 2 && faw_count == 4) || (seq.faw_test == 1 && faw_count == 5)) begin

          repeat(`TRCD)

              @(vif.ddr5_drv_cb_t);

              faw_count = 0;

        end

      end else begin

        activate(seq);

        repeat(`TRCD) @(vif.ddr5_drv_cb_t);

      end

      have_last_rw = 1'b0;

    end
 
    WRITE, WRITE_AP: begin
      
      case(seq.bl)
        
        BL32     : write_bl32(seq);

        BL32_OTF : write_bl32_otf(seq);

        default  : write(seq);
      
      endcase

      have_last_rw = 1'b1;

      last_rw_cmd = WRITE;

      last_rw_bg = seq.bg;

      last_write_bl16 = (seq.bl == BL16);

      // Preserve the existing WRITE_AP recovery wait.

      if (seq.cmd == WRITE_AP) repeat(`TWR) @(vif.ddr5_drv_cb_t);

    end
 
    READ, READ_AP: begin

      read(seq);

      have_last_rw = 1'b1;

      last_rw_cmd = READ;

      last_rw_bg = seq.bg;

      last_write_bl16 = 1'b0;

      if (seq.cmd == READ_AP) repeat(`TRTP) @(vif.ddr5_drv_cb_t);

    end
 
    MRW: begin

      bit [7:0] mr_opcode;

      if (seq.mra == 8'd8)

        mr_opcode = {seq.wr_postamble, seq.rd_postamble, 1'b0, seq.wr_preamble, seq.rd_preamble};

      else

        mr_opcode = seq.mr_opcode;

      mrw(seq.mra, mr_opcode);

      have_last_rw = 1'b0;

    end
 
    PRECHARGE: begin precharge(seq); have_last_rw = 1'b0; end
 
    PRECHARGE_SB: begin precharge_sb(seq); have_last_rw = 1'b0; end
 
    PRECHARGE_ALL: begin precharge_all(); have_last_rw = 1'b0; end
 
    PD_E : begin powerdown_entry(); have_last_rw = 1'b0; end
 
    PD_X: begin powerdown_exit(); have_last_rw = 1'b0; end
 
    default: `uvm_error("DDR5_DRV", $sformatf("Unsupported command: %0d", seq.cmd))

  endcase

endtask
 
endclass
 
 
 
 


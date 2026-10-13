class ddr5_scoreboard extends uvm_scoreboard;
 `include "../config/ddr5_timingpar.sv"
  `uvm_component_utils(ddr5_scoreboard)
  // Analysis Port
  uvm_analysis_imp #(ddr5_seq_item, ddr5_scoreboard) sb_port;
bit [`DATA_WIDTH-1:0] mem [bit [`BG_WIDTH-1:0]][bit [`BA_WIDTH-1:0]][bit [`ROW_WIDTH-1:0]][bit [`COL_WIDTH-1:0]];
 
bit bank_active [bit [`BG_WIDTH-1:0]][bit [`BA_WIDTH-1:0]];
 
bit [`ROW_WIDTH-1:0] active_row [bit [`BG_WIDTH-1:0]][bit [`BA_WIDTH-1:0]];
	realtime tCK;
	realtime current_time;
	realtime activate_time[$];
   function new(string name = "ddr5_scoreboard",uvm_component parent = null);
    super.new(name,parent);
    sb_port = new("sb_port",this);
  endfunction

  function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db#(realtime)::get(this, "", "tCK", tCK))
    `uvm_fatal("DDR5_SB", "tCK not configured")
  `uvm_info("DDR5_SB", $sformatf("tCK = %0.3f ns", tCK), UVM_LOW)
endfunction

  function void compare(
    bit [`BG_WIDTH-1:0] bg,
    bit [`BA_WIDTH-1:0] ba,
    bit [`ROW_WIDTH-1:0] row,
    bit [`COL_WIDTH-1:0] col,
    int beat,
    bit [`DATA_WIDTH-1:0] actual,
    bit [`DATA_WIDTH-1:0] expected
  );
    if (actual === expected) begin
      `uvm_info("DDR5_SB_PASS", $sformatf("MATCH BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d EXP=%0h ACT=%0h", bg, ba, row, col, beat, expected, actual), UVM_LOW)
    end
    else begin
`uvm_error("DDR5_SB_FAIL", $sformatf("MISMATCH BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d EXP=%0h ACT=%0h", bg, ba, row, col, beat, expected, actual))
    end
  endfunction
  // Monitor -> Scoreboard
  function void write(ddr5_seq_item seq);
    bit [`ROW_WIDTH-1:0] row;
    bit [`COL_WIDTH-1:0] col_addr;
    bit [`DATA_WIDTH-1:0] expected;
    case (seq.cmd)
      // ACTIVATE
    ACTIVATE: begin
  current_time = seq.command_time;

  while (activate_time.size() > 0 && (current_time - activate_time[0]) >= (`TFAW * tCK))
    activate_time.pop_front();

  if (activate_time.size() >= 4)
    `uvm_error("DDR5_FAW_VIOLATION", $sformatf("FAW violation: 5th or later ACTIVATE within tFAW. BG=%0d BA=%0d ROW=%0d TIME=%0t OLDEST_ACT=%0t", seq.bg, seq.ba, seq.row, current_time, activate_time[0]))
  else
    `uvm_info("DDR5_FAW", $sformatf("ACTIVATE count=%0d BG=%0d BA=%0d ROW=%0d TIME=%0t", activate_time.size()+1, seq.bg, seq.ba, seq.row, current_time), UVM_LOW)

  activate_time.push_back(current_time);
  active_row[seq.bg][seq.ba] = seq.row;
  bank_active[seq.bg][seq.ba] = 1'b1;
end 
      // WRITE
     WRITE: begin
  bit preamble_valid;
  bit dqs_valid;
  int preamble_samples;
  if (!bank_active[seq.bg][seq.ba]) begin
    `uvm_error("DDR5_SB", $sformatf("WRITE ON CLOSED BANK BG=%0d BA=%0d", seq.bg, seq.ba))
    return;
  end
  row = active_row[seq.bg][seq.ba];
  `uvm_info("DDR5_SB", $sformatf("WRITE BG=%0d BA=%0d ROW=%0d COL=%0d WR_PRE=%0d", seq.bg, seq.ba, row, seq.col, seq.wr_preamble), UVM_LOW)
  preamble_valid = 1'b1;
  case (seq.wr_preamble)
    WR_PRE_2TCK: begin
      preamble_samples = 4;
      for (int i = 0; i < preamble_samples; i++) begin
        if ((seq.dqs_t_preamble[i] !== ((i == 2) ? 1'b1 : 1'b0)) ||
            (seq.dqs_c_preamble[i] !== ((i == 2) ? 1'b0 : 1'b1))) begin
          preamble_valid = 1'b0;
          `uvm_error("DDR5_SB_PRE",
            $sformatf("2TCK WRITE PREAMBLE INVALID SAMPLE=%0d DQS_T=%b DQS_C=%b",
            i, seq.dqs_t_preamble[i], seq.dqs_c_preamble[i]))
          break;
        end
      end
      if (preamble_valid)
        `uvm_info("DDR5_SB_PRE", "2TCK WRITE PREAMBLE 0010 VALID", UVM_LOW)
    end
    WR_PRE_3TCK: begin
      preamble_samples = 6;
      for (int i = 0; i < preamble_samples; i++) begin
        if ((seq.dqs_t_preamble[i] !== ((i == 4) ? 1'b1 : 1'b0)) ||
            (seq.dqs_c_preamble[i] !== ((i == 4) ? 1'b0 : 1'b1))) begin
          preamble_valid = 1'b0;
          `uvm_error("DDR5_SB_PRE",
            $sformatf("3TCK WRITE PREAMBLE INVALID SAMPLE=%0d DQS_T=%b DQS_C=%b",
            i, seq.dqs_t_preamble[i], seq.dqs_c_preamble[i]))
          break;
        end
      end
      if (preamble_valid)
        `uvm_info("DDR5_SB_PRE", "3TCK WRITE PREAMBLE 000010 VALID", UVM_LOW)
    end
    WR_PRE_4TCK: begin
      preamble_samples = 8;
      for (int i = 0; i < preamble_samples; i++) begin
        if ((seq.dqs_t_preamble[i] !== (((i == 4) || (i == 6)) ? 1'b1 : 1'b0)) ||
            (seq.dqs_c_preamble[i] !== (((i == 4) || (i == 6)) ? 1'b0 : 1'b1))) begin
          preamble_valid = 1'b0;
          `uvm_error("DDR5_SB_PRE",
            $sformatf("4TCK WRITE PREAMBLE INVALID SAMPLE=%0d DQS_T=%b DQS_C=%b",
            i, seq.dqs_t_preamble[i], seq.dqs_c_preamble[i]))
          break;
        end
      end
      if (preamble_valid)
        `uvm_info("DDR5_SB_PRE", "4TCK WRITE PREAMBLE 00001010 VALID", UVM_LOW)
    end
    default: begin
      preamble_valid = 1'b0;
      `uvm_error("DDR5_SB_PRE",
        $sformatf("INVALID WRITE PREAMBLE MODE=%0d", seq.wr_preamble))
    end
  endcase
  if (!preamble_valid) begin
    `uvm_error("DDR5_SB_WRITE",
      "WRITE DATA NOT STORED BECAUSE WRITE PREAMBLE IS INVALID")
    return;
  end
  dqs_valid = 1'b1;
  if ((seq.dqs_t_burst[0] !== 1'b1) ||
      (seq.dqs_c_burst[0] !== 1'b0)) begin
    dqs_valid = 1'b0;
    `uvm_error("DDR5_SB_DQS",
      $sformatf("WRITE DQS INITIAL STATE INVALID DQS_T=%b DQS_C=%b",
      seq.dqs_t_burst[0], seq.dqs_c_burst[0]))
  end
  if (dqs_valid) begin
    for (int i = 1; i < 16; i++) begin
      if ((seq.dqs_t_burst[i] === seq.dqs_t_burst[i-1]) ||
          (seq.dqs_c_burst[i] === seq.dqs_c_burst[i-1]) ||
          (seq.dqs_t_burst[i] === seq.dqs_c_burst[i])) begin
        dqs_valid = 1'b0;
        `uvm_error("DDR5_SB_DQS",
          $sformatf("WRITE DQS TOGGLING INVALID BEAT=%0d DQS_T=%b DQS_C=%b",
          i, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))
        break;
      end
    end
  end
  if (dqs_valid) begin
    `uvm_info("DDR5_SB_DQS",
      "WRITE PREAMBLE VALID + WRITE DQS VALID - STORING DATA", UVM_LOW)
    for (int i = 0; i < 16; i++) begin
      col_addr = seq.col + i;
      mem[seq.bg][seq.ba][row][col_addr] = seq.dq_burst[i];
      `uvm_info("DDR5_SB_WRITE",
        $sformatf("STORE BG=%0d BA=%0d ROW=%0d COL=%0d DATA=%0d",
        seq.bg, seq.ba, row, col_addr, seq.dq_burst[i]), UVM_LOW)
    end
  end
  else begin
    `uvm_error("DDR5_SB_WRITE",
      "WRITE DATA NOT STORED BECAUSE WRITE DQS IS INVALID")
  end
end
READ: begin
  bit dqs_preamble_valid;
  bit dqs_toggling;
  if (!bank_active[seq.bg][seq.ba]) begin
    `uvm_error("DDR5_SB_READ", $sformatf("READ ON CLOSED BANK BG=%0d BA=%0d", seq.bg, seq.ba))
    return;
  end
  row = active_row[seq.bg][seq.ba];
  `uvm_info("DDR5_SB", $sformatf("READ BG=%0d BA=%0d ROW=%0d COL=%0d", seq.bg, seq.ba, row, seq.col), UVM_LOW)
  dqs_preamble_valid = 1;
  dqs_toggling       = 0;
  // Check DQS preamble
  for (int i = 0; i < 8; i++) begin
    if ((seq.dqs_t_preamble[i] !== 1'b0 && seq.dqs_t_preamble[i] !== 1'b1) ||
        (seq.dqs_c_preamble[i] !== 1'b0 && seq.dqs_c_preamble[i] !== 1'b1)) begin
      dqs_preamble_valid = 0;
      `uvm_error("DDR5_SB_READ_DQS_PREAMBLE", $sformatf("READ DQS PREAMBLE NOT DETECTED AT SAMPLE=%0d DQS_T=%b DQS_C=%b", i, seq.dqs_t_preamble[i], seq.dqs_c_preamble[i]))
      break;
    end
  end
  // Check DQS toggling
  if (dqs_preamble_valid) begin
    for (int i = 1; i < 16; i++) begin
      if ((seq.dqs_t_burst[i] !== seq.dqs_t_burst[i-1]) ||
          (seq.dqs_c_burst[i] !== seq.dqs_c_burst[i-1])) begin
        dqs_toggling = 1;
        break;
      end
    end
  end
  if (!dqs_toggling) begin
    `uvm_error("DDR5_SB_READ_DQS_TOGGLE", "READ DQS IS NOT TOGGLING")
  end
  // Compare BL16 data only for valid DQS response
  if (dqs_preamble_valid && dqs_toggling) begin
    for (int i = 0; i < 16; i++) begin
      col_addr = seq.col + i;
      if (mem[seq.bg][seq.ba][row].exists(col_addr)) begin
        expected = mem[seq.bg][seq.ba][row][col_addr];
        compare(seq.bg, seq.ba, row, col_addr, i, seq.dq_burst[i], expected);
      end
      else begin
        `uvm_error("DDR5_SB_READ", $sformatf("READ ADDRESS NEVER WRITTEN BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d", seq.bg, seq.ba, row, col_addr, i))
      end
    end
  end
  else begin
    `uvm_info("DDR5_SB_READ", "READ DATA COMPARISON SKIPPED DUE TO INVALID DQS RESPONSE", UVM_LOW)
  end
end

 
    endcase
  endfunction
endclass

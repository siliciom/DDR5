class ddr5_monitor extends uvm_monitor;
 
  `uvm_component_utils(ddr5_monitor)
 
  virtual ddr5_interface vif;
 
  uvm_analysis_port #(ddr5_seq_item) ddr5_ap;
 
  ddr5_seq_item tr;
 
  bit [2:0] current_rd_preamble;

  bit [1:0] current_wr_preamble;

  burst_length_e current_bl;
 
  bit [`ROW_WIDTH-1:0] active_row

      [0:(1<<`BG_WIDTH)-1]

      [0:(1<<`BA_WIDTH)-1];
 
  bit bank_active

      [0:(1<<`BG_WIDTH)-1]

      [0:(1<<`BA_WIDTH)-1];
 
  int rd_preamble_tck;

  int rd_preamble_samples;
 
  // Consecutive normal BL16 WRITE tracking

  longint unsigned ck_cycle_count = 0;

  longint unsigned prev_write_cycle = 0;

  bit have_prev_write = 1'b0;

  bit [`BG_WIDTH-1:0] prev_write_bg = '0;

  bit prev_write_bl16 = 1'b0;

  bit bl32_write_cmd_seen = 0;
  
  bit bl32_read_cmd_seen = 0;
 
  ddr5_seq_item mon_txn_q[$];

semaphore mon_q_sem = new(1);
 
 
  function new(string name = "ddr5_monitor", uvm_component parent = null);

    super.new(name, parent);
 
    ddr5_ap = new("ddr5_ap", this);
 
    current_rd_preamble = 3'b000;

    current_wr_preamble = 2'b00;
 
  endfunction
 
 
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);
 
    if (!uvm_config_db#(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif))

      `uvm_fatal("MON", "NO INTERFACE")

  endfunction
 
 
  task run_phase(uvm_phase phase);

    fork

      monitor_commands();

      monitor_reset();

      count_ck_cycles();

    publish_transactions();      

    join

  endtask
 
  // Count CK cycles independently of command/data capture.

  task count_ck_cycles();

    forever begin

      @(vif.ddr5_mon_cb_t);

      ck_cycle_count++;

    end

  endtask
 
task monitor_commands();

  forever begin

    sample_command();

  end

endtask
 
 
task publish_transactions();

  ddr5_seq_item item;
 
  forever begin

    // Wait until a transaction is available.

    wait (mon_txn_q.size() > 0);
 
    mon_q_sem.get(1);

    item = mon_txn_q[0];

    mon_q_sem.put(1);
 
    // Wait until the transaction's data capture is complete.

    wait (item.data_capture_done == 1'b1);
 
    // Remove the transaction from the queue.

    mon_q_sem.get(1);

    if ((mon_txn_q.size() > 0) &&

        (mon_txn_q[0] == item)) begin

      mon_txn_q.pop_front();

    end

    mon_q_sem.put(1);
 
    // Log immediately before publishing to the scoreboard.

    `uvm_info("MON_TO_SB",

      $sformatf(

        "SENDING TO SCOREBOARD: CMD=%s BG=%0d BA=%0d ROW=%0d COL=%0d",

        item.cmd.name(), item.bg, item.ba, item.row, item.col

      ),

      UVM_LOW)
 
    // Print every captured data beat for READ/WRITE transactions.

    if (item.cmd inside {READ, READ_AP, WRITE, WRITE_AP}) begin

      int burst_limit;

      if (item.full_bl32)
        burst_limit = 32;
      else if ((item.bl == BC8_OTF) && (item.ca5 == 1'b0))
        burst_limit = 8;
      else
        burst_limit = 16;

      for(int i=0;i<burst_limit;i++) begin

        int disp_idx;

        disp_idx = i;

        if(item.bc8_upper_half)
          disp_idx = i + 8;
        else if(item.bl32_upper_half)
          disp_idx = i + 16;

          `uvm_info("MON_TO_SB",
              $sformatf("WRITE DQ[%0d]=%0h",
                disp_idx, 
                item.dq_burst[i]), UVM_LOW)

        end
    end
     
    // Publish the transaction.

    ddr5_ap.write(item);

  end

endtask
 
  task enqueue_transaction(ddr5_seq_item item);

  mon_q_sem.get(1);

  mon_txn_q.push_back(item);

  mon_q_sem.put(1);

endtask
 
task handle_reset();
 
  `uvm_info("DDR5_MON", "STABLE-POWER RESET DETECTED - CLEARING MONITOR STATE", UVM_LOW)
 
  for (int bg = 0; bg < (1<<`BG_WIDTH); bg++) begin

    for (int ba = 0; ba < (1<<`BA_WIDTH); ba++) begin

      active_row[bg][ba] = '0;

      bank_active[bg][ba] = 1'b0;

    end

  end
 
  current_rd_preamble = 3'b000;

  current_wr_preamble = 2'b01;

  have_prev_write = 1'b0;

  prev_write_cycle = 0;

  prev_write_bg = '0;

  prev_write_bl16 = 1'b0;

  ck_cycle_count = 0;
 
  `uvm_info("DDR5_MON", "MONITOR BANK STATE CLEARED AFTER RESET", UVM_LOW)
 
endtask
 
 
    task monitor_reset();
 
  ddr5_seq_item reset_tr;
 
  forever begin
 
    // RESET_n is asynchronous

    @(negedge vif.reset_n);
 
    `uvm_info("DDR5_MON",

              "STABLE-POWER RESET DETECTED - RESET_n LOW",

              UVM_LOW)
 
    // Clear monitor internal state

    handle_reset();
 
    

    reset_tr = ddr5_seq_item::type_id::create("reset_tr", this);
 
    reset_tr.reset_n = 1'b0;
 
    

    ddr5_ap.write(reset_tr);
 
    `uvm_info("DDR5_MON", "RESET TRANSACTION SENT TO SCOREBOARD", UVM_LOW)
 
    // Wait for reset release

    @(posedge vif.reset_n);
 
    `uvm_info("DDR5_MON", "STABLE-POWER RESET RELEASED - RESET_n HIGH", UVM_LOW)
 
  end
 
endtask
 
 


  // Sample Command
 
task sample_command();

  bit [13:0] ca1;

  bit [13:0] ca2;
 
  forever begin
 
    // Wait for a monitor clocking event.

    @(vif.ddr5_mon_cb_t);
 
    // Do not monitor commands while reset is active.

    if (vif.ddr5_mon_cb_t.reset_n !== 1'b1)

      continue;
 
    

    // Wait until CS_n is HIGH after reset initialization.

    // CS_n remains LOW during part of the reset sequence.

    wait (vif.ddr5_mon_cb_t.reset_n === 1'b1);

    wait (vif.ddr5_mon_cb_t.cs_n === 1'b1);
 
    // Wait for the first CA phase of the next command.

    wait (vif.ddr5_mon_cb_t.cs_n === 1'b0);
 
    if (vif.ddr5_mon_cb_t.reset_n !== 1'b1)

      continue;
 
    ca1 = vif.ddr5_mon_cb_t.ca;
 
    `uvm_info("DDR5_MON",

      $sformatf("CA1 Captured = %014b", ca1),

      UVM_LOW)
 
    // Wait for the second CA phase.

    @(vif.ddr5_mon_cb_t);
 
    if (vif.ddr5_mon_cb_t.reset_n !== 1'b1)

      continue;
 
    wait (vif.ddr5_mon_cb_t.cs_n === 1'b1);
 
    ca2 = vif.ddr5_mon_cb_t.ca;
 
    `uvm_info("DDR5_MON", $sformatf("CA2 Captured = %014b", ca2), UVM_LOW)
 
    `uvm_info("MON_CA_DEBUG", $sformatf("CA1=%014b CA2=%014b", ca1, ca2), UVM_LOW)
 
    //  NOP commands.

    if (ca1[4:0] == 5'b11111) begin

      `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)

    end

    else begin

      decode_command(ca1, ca2);

    end
 
  end

endtask
 


  // Command Decoder
 
  task decode_command(

    input bit [13:0] ca1,

    input bit [13:0] ca2

  );
 
 
    tr = ddr5_seq_item::type_id::create("tr", this);

    tr.reset_n = 1'b1;

    tr.cmd = DES;
 
    

// PRECHARGE

if (ca1[13:8] == 6'b010110) begin

  tr.cmd = PRECHARGE;

end
 
// PRECHARGE ALL / PRECHARGE SAME BANK
 
else if (ca1[13:8] == 6'b011010) begin

  if (ca1[7:0] == 8'b0)

    tr.cmd = PRECHARGE_ALL;

  else

    tr.cmd = PRECHARGE_SB;

end
 
// ACTIVATE

else if ((ca1[13:11] == 3'b000) &&

         (ca1[1:0] == 2'b00)) begin

  tr.cmd = ACTIVATE;

end
 
else begin

  case (ca1[4:0])

    5'b00101: tr.cmd = MRW;
 
    5'b01101: begin

      if (ca2[10])

        tr.cmd = WRITE;

      else

        tr.cmd = WRITE_AP;

    end
 
    5'b11101: begin

      if (ca2[10])

        tr.cmd = READ;

      else

        tr.cmd = READ_AP;

    end
 
    5'b11111: tr.cmd = NOP;
 
    default: tr.cmd = DES;

  endcase

end

`uvm_info("MON_CMD_DEBUG",

    $sformatf("Decoded command=%s BG=%0d BA=%0d CA1=%014b CA2=%014b",

              tr.cmd.name(), tr.bg, tr.ba, ca1, ca2),

    UVM_LOW)
 
    // A non-WRITE command interrupts the normal WRITE chain.

    if ((tr.cmd != WRITE) && (tr.cmd != NOP))

      have_prev_write = 1'b0;
 
    case (tr.cmd)
 
      NOP: begin

        `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)

      end
 
 
      

      // MRW

    MRW: begin

  tr.mra       = ca1[12:5];

  tr.mr_opcode = ca2[7:0];

  if (tr.mra == 8'd0) begin

  case (tr.mr_opcode[1:0])

    2'b00 : current_bl = BL16;
    2'b01 : current_bl = BC8_OTF;
    2'b10 : current_bl = BL32;
    2'b11 : current_bl = BL32_OTF;

  endcase

    `uvm_info("MON_MR0_DEBUG", $sformatf("MR0 DETECTED : BL=%s",
              current_bl.name()), UVM_LOW)

  end
 
  if (tr.mra == 8'd8) begin
 
  current_rd_preamble = tr.mr_opcode[2:0];

  current_wr_preamble = tr.mr_opcode[4:3];
 
  `uvm_info("MON_MR8_DEBUG",$sformatf("MR8 opcode=%02h WR_PRE_BITS=%b WR_PRE=%0d", tr.mr_opcode, tr.mr_opcode[4:3], current_wr_preamble ),UVM_LOW)
 
end

  ddr5_ap.write(tr);

end
 
 
     

      // WRITE

      WRITE: begin

        monitor_write(ca1, ca2, 1'b0);

      end
 
 
      

      // WRITE_AP

      WRITE_AP: begin

        monitor_write(ca1, ca2, 1'b1);

      end
 
 
      // READ

      READ: begin

        monitor_read( ca1, ca2, 1'b0);

      end
 
 
      // READ_AP

      READ_AP: begin

        monitor_read(ca1, ca2, 1'b1);

      end
 
 
            // ACTIVATE
 
      ACTIVATE: begin
 
        tr.bg = ca1[10:8];

        tr.ba = ca1[7:6];
 
        tr.row[3:0] = ca1[5:2];

        tr.row[17:4] = ca2;
 
        active_row[tr.bg][tr.ba] = tr.row;

        bank_active[tr.bg][tr.ba] = 1'b1;

        `uvm_info("MON_BANK_STATE",

    $sformatf("AFTER ACTIVATE: BG=%0d BA=%0d OPEN=%0b ROW=%0d",

              tr.bg, tr.ba,

              bank_active[tr.bg][tr.ba],

              active_row[tr.bg][tr.ba]),

    UVM_LOW)
 
        `uvm_info("DDR5_MON", $sformatf("ACTIVATE : BG=%0d BA=%0d ROW=%0d", tr.bg, tr.ba, tr.row), UVM_LOW)
 
        tr.data_capture_done = 1'b1;

        enqueue_transaction(tr);
 
      end
 
      PRECHARGE: begin

            monitor_precharge(tr, ca1);

        end
 
      PRECHARGE_ALL: begin

            monitor_precharge_all();

        end
 
      PRECHARGE_SB: begin

            monitor_precharge_sb(tr, ca1);

        end
 
 
      default: begin

        `uvm_warning("DDR5_MON", $sformatf("DES CMD : CA1=%014b CA2=%014b", ca1, ca2))

      end
 
    endcase
 
  endtask
 
 
  

// PRECHARGE: One bank in one bank group

task monitor_precharge(

    ref ddr5_seq_item tr,

    input bit [13:0] ca

);

    tr.cmd = PRECHARGE;
 
    tr.ba = {ca[7], ca[6]};

    tr.bg = {ca[5], ca[4], ca[3]};
 
    if (bank_active[tr.bg][tr.ba]) begin

        bank_active[tr.bg][tr.ba] = 1'b0;

        active_row[tr.bg][tr.ba] = '0;

    end

    else begin

        `uvm_warning("DDR5_MON",

            $sformatf("PRE on inactive bank: BG=%0d BA=%0d",

                      tr.bg, tr.ba))

    end
 
    `uvm_info("DDR5_MON",

        $sformatf("PRE | BG=%0d BA=%0d", tr.bg, tr.ba),

        UVM_LOW)
 
    tr.data_capture_done = 1'b1;

    enqueue_transaction(tr);

endtask
 
 
// PRECHARGE ALL: All banks in all bank groups

task monitor_precharge_all();
 
    tr.cmd     = PRECHARGE_ALL;

    tr.bg      = '0;

    tr.ba      = '0;
 
    foreach (bank_active[bg, ba]) begin

        bank_active[bg][ba] = 1'b0;

        active_row[bg][ba]  = '0;

    end
 
    `uvm_info("DDR5_MON", "PRECHARGE ALL detected", UVM_LOW)
 
   tr.data_capture_done = 1'b1;

   enqueue_transaction(tr);
 
endtask
 
 
// PRECHARGE SAME BANK: Same bank number across BGs
 
task monitor_precharge_sb(ref ddr5_seq_item tr, input bit [13:0] ca);
 
    bit [1:0] target_ba;
 
    target_ba = {ca[6], ca[7]};
 
    tr.cmd     = PRECHARGE_SB;

    tr.bg      = '0;

    tr.ba      = target_ba;
 
    foreach (bank_active[bg, ba]) begin

        if (ba == target_ba) begin

            bank_active[bg][ba] = 1'b0;

            active_row[bg][ba]  = '0;

        end

    end
 
    `uvm_info("DDR5_MON",$sformatf("PRECHARGE SAME BANK | BA=%0d", target_ba), UVM_LOW)
 
    tr.data_capture_done = 1'b1;

   enqueue_transaction(tr); 

endtask
 
 
  //==========================================================

  // Common WRITE / WRITE_AP Processing

  // Each write owns a separate transaction and data-capture thread.

  //==========================================================

  task monitor_write(

    input bit [13:0] ca1,

    input bit [13:0] ca2,

    input bit auto_precharge

  );
 
    ddr5_seq_item wr_tr;

    longint unsigned current_write_cycle;

    longint unsigned tccd_cycles;

    bit current_bl16;
 
    wr_tr = ddr5_seq_item::type_id::create("wr_tr", this);

    wr_tr.cmd = auto_precharge ? WRITE_AP : WRITE;

    wr_tr.reset_n = 1'b1;
 
    wr_tr.bg = ca1[10:8];

    wr_tr.ba = ca1[7:6];

    wr_tr.bl  = current_bl;

    wr_tr.ca5 = ca1[5];

    wr_tr.full_bl32 = ((wr_tr.bl == BL32) ||
                        ((wr_tr.bl == BL32_OTF) && (wr_tr.ca5 == 1'b0)));
    
    if (`DATA_WIDTH == 4) begin
    
      if (wr_tr.full_bl32)
        wr_tr.col = {1'b0, ca2[7:1], 3'b000};
      else
        wr_tr.col = {ca2[8:1], 3'b000};
    end

    else

      wr_tr.col = {ca2[7:1], 3'b000};


    wr_tr.bc8_upper_half = ((wr_tr.bl == BC8_OTF) &&
                            (wr_tr.ca5 == 1'b0) && (wr_tr.col[3] == 1'b1));

    wr_tr.bl32_upper_half = ((wr_tr.bl == BL32_OTF) &&
                              (wr_tr.ca5 == 1'b1) && (wr_tr.col[10] == 1'b1));

      `uvm_info("MON_BURST_MODE",
        $sformatf("WRITE BL=%s CA5=%0d COL=%0d FULL_BL32=%0b BC8_UPPER=%0b BL32_UPPER=%0b",
          wr_tr.bl.name(),
          wr_tr.ca5,
          wr_tr.col,
          wr_tr.full_bl32,
          wr_tr.bc8_upper_half,
          wr_tr.bl32_upper_half),
        UVM_LOW)

   if (wr_tr.full_bl32) begin

    if (!bl32_write_cmd_seen) begin

      bl32_write_cmd_seen = 1'b1;

      `uvm_info("BL32_MON",
      "FIRST BL32 WRITE DETECTED - WAITING FOR SECOND WRITE",
      UVM_LOW)

      return;

    end

    bl32_write_cmd_seen = 1'b0;

      `uvm_info("BL32_MON",
        "SECOND BL32 WRITE DETECTED - STARTING DATA CAPTURE",
          UVM_LOW)

   end
 
    
    wr_tr.wr_preamble = current_wr_preamble;

      `uvm_info("MON_BANK_STATE",

        $sformatf("BEFORE WRITE: BG=%0d BA=%0d OPEN=%0b",

              wr_tr.bg, wr_tr.ba,

              bank_active[wr_tr.bg][wr_tr.ba]),

    UVM_LOW)

    if (bank_active[wr_tr.bg][wr_tr.ba]) begin

      wr_tr.row = active_row[wr_tr.bg][wr_tr.ba];

    end

    else begin

      wr_tr.row = '0;

      `uvm_error("DDR5_MON", $sformatf("%s detected on inactive bank BG=%0d BA=%0d", auto_precharge ? "WRITE_AP" : "WRITE", wr_tr.bg, wr_tr.ba))

    end
 
    current_write_cycle = ck_cycle_count;

    // Keep the existing driver's command encoding assumption.

    current_bl16 = (ca1[5] == 1'b0);

    tccd_cycles = 0;

    wr_tr.seamless_write = 1'b0;

    wr_tr.observed_write_tccd = 0;
 
    if (!auto_precharge) begin

      if (have_prev_write) begin

        tccd_cycles = current_write_cycle - prev_write_cycle;
 
        if ((wr_tr.bg != prev_write_bg) &&

            prev_write_bl16 && current_bl16 &&

            (tccd_cycles == 8))

          wr_tr.seamless_write = 1'b1;
 
        if ((wr_tr.bg != prev_write_bg) &&

            prev_write_bl16 && current_bl16 &&

            (tccd_cycles >= 8) && (tccd_cycles <= 13))

          wr_tr.observed_write_tccd = int'(tccd_cycles);

      end
 
      have_prev_write = 1'b1;

      prev_write_bg = wr_tr.bg;

      prev_write_cycle = current_write_cycle;

      prev_write_bl16 = current_bl16;

    end

    else begin

      have_prev_write = 1'b0;

    end
 
    `uvm_info("MON_SEAMLESS",

      $sformatf("WRITE BG=%0d PREV_BG=%0d TCCD=%0d BL16=%0b SEAMLESS=%0b",

        wr_tr.bg, prev_write_bg, tccd_cycles, current_bl16,

        wr_tr.seamless_write), UVM_LOW)
 
    `uvm_info("DDR5_MON", $sformatf("%s : BG=%0d BA=%0d ROW=%0d COL=%0d WR_PRE=%0d", auto_precharge ? "WRITE_AP" : "WRITE", wr_tr.bg, wr_tr.ba, wr_tr.row, wr_tr.col, wr_tr.wr_preamble), UVM_LOW)
 
    // Preserve bank-state update at command decode, not after data capture.

    // This lets later commands be decoded while DQ capture is in progress.

    if (auto_precharge) begin

      bank_active[wr_tr.bg][wr_tr.ba] = 1'b0;

      active_row[wr_tr.bg][wr_tr.ba] = '0;

    end
 
    wr_tr.data_capture_done = 1'b0;

enqueue_transaction(wr_tr);
 
    fork

      capture_write_and_send(wr_tr);

    join_none
 
  endtask
 
  task automatic capture_write_and_send(ddr5_seq_item wr_tr);
 
  sample_write_data(wr_tr);
 
  `uvm_info("MON_SB", $sformatf("WRITE data capture complete: CMD=%s", wr_tr.cmd.name()), UVM_LOW)
 
  // Mark this exact WRITE transaction as ready.

  wr_tr.data_capture_done = 1'b1;
 
endtask
 
  

  // Common READ / READ_AP Processing

task monitor_read(

    input bit [13:0] ca1,

    input bit [13:0] ca2,

    input bit        auto_precharge

);
 
    ddr5_seq_item rd_tr;
 
    rd_tr = ddr5_seq_item::type_id::create("rd_tr", this);

    rd_tr.reset_n = 1'b1;

    rd_tr.cmd = auto_precharge ? READ_AP : READ;
 
    // Decode bank and column.

    rd_tr.bg = ca1[10:8];

    rd_tr.ba = ca1[7:6];

    rd_tr.bl  = current_bl;
    
    rd_tr.ca5 = ca1[5];

    rd_tr.full_bl32 = ((rd_tr.bl == BL32) ||
                       ((rd_tr.bl == BL32_OTF) && (rd_tr.ca5 == 1'b0)));
 
    if (`DATA_WIDTH == 4) begin
      
      if (rd_tr.full_bl32)
        rd_tr.col = {1'b0, ca2[7:1], 3'b000};
      else
        rd_tr.col = {ca2[8:1], 3'b000};
    end

    else

        rd_tr.col = {ca2[7:1], 3'b000};
 
    rd_tr.rd_preamble = current_rd_preamble;

     rd_tr.bc8_upper_half = ((rd_tr.bl == BC8_OTF) &&
                            (rd_tr.ca5 == 1'b0) && (rd_tr.col[3] == 1'b1));

    rd_tr.bl32_upper_half = ((rd_tr.bl == BL32_OTF) &&
                             (rd_tr.ca5 == 1'b1) && (rd_tr.col[10] == 1'b1));

    `uvm_info("READ_BURST_MODE",
      $sformatf("READ BL=%s CA5=%0d COL=%0d FULL_BL32=%0b BC8_UPPER=%0b BL32_UPPER=%0b",
          rd_tr.bl.name(),
          rd_tr.ca5,
          rd_tr.col,
          rd_tr.full_bl32,
          rd_tr.bc8_upper_half,
          rd_tr.bl32_upper_half),
      UVM_LOW)
 
   if (rd_tr.full_bl32) begin

    if (!bl32_read_cmd_seen) begin

      bl32_read_cmd_seen = 1'b1;

      `uvm_info("BL32_READ_MON",
      "FIRST BL32 READ DETECTED - WAITING FOR SECOND READ",
      UVM_LOW)

      return;

    end

    bl32_read_cmd_seen = 1'b0;

    `uvm_info("BL32_READ_MON",
    "SECOND BL32 READ DETECTED - STARTING DATA CAPTURE",
      UVM_LOW)

   end
    // Capture the row associated with the READ command.

    if (bank_active[rd_tr.bg][rd_tr.ba]) begin

        rd_tr.row = active_row[rd_tr.bg][rd_tr.ba];

    end

    else begin

        rd_tr.row = '0;

        `uvm_error("DDR5_MON",

            $sformatf("%s detected on inactive bank BG=%0d BA=%0d",

                auto_precharge ? "READ_AP" : "READ",

                rd_tr.bg, rd_tr.ba))

    end
 
    `uvm_info("DDR5_MON", $sformatf("%s COMMAND: BG=%0d BA=%0d ROW=%0d COL=%0d", auto_precharge ? "READ_AP" : "READ", rd_tr.bg, rd_tr.ba, rd_tr.row, rd_tr.col), UVM_LOW)
 
        // Queue READ before starting data capture.

        // It cannot be published until capture completes.

        rd_tr.data_capture_done = 1'b0;

        enqueue_transaction(rd_tr);
 
// Update monitor bank state for READ_AP.

if (auto_precharge) begin

  bank_active[rd_tr.bg][rd_tr.ba] = 1'b0;

  active_row[rd_tr.bg][rd_tr.ba] = '0;

end
 
fork

  begin

    sample_read_data(rd_tr);
 
    // Mark complete only after the capture task returns.

    rd_tr.data_capture_done = 1'b1;
 
//    `uvm_info("DDR5_MON", $sformatf("%s DATA CAPTURE COMPLETE: BG=%0d BA=%0d", auto_precharge ? "READ_AP" : "READ", rd_tr.bg, rd_tr.ba), UVM_LOW)
 
  end
 
join_none
 
    endtask
 
    //==========================================================

  // Sample WRITE Data

  //==========================================================
 
task sample_write_data(ddr5_seq_item tr);
 
  int preamble_tck;

  int preamble_samples;

  int preamble_wait_cycles;

  int dq_wait_cycles;

  int burst_limit;

  if (tr.full_bl32)
    burst_limit = 32;
  else if ((tr.bl == BC8_OTF) && (tr.ca5 == 1'b0))
    burst_limit = 8;
  else
    burst_limit = 16;

    `uvm_info("MON_BURST_MODE", $sformatf("WRITE BL=%s CA5=%0d BURST_LIMIT=%0d",
            tr.bl.name(),
            tr.ca5,
            burst_limit),
            UVM_LOW)
 
  case (tr.wr_preamble)
 
    WR_PRE_2TCK: preamble_tck = 2;

    WR_PRE_3TCK: preamble_tck = 3;

    WR_PRE_4TCK: preamble_tck = 4;
 
    default: begin

      preamble_tck = 2;

      `uvm_warning("DDR5_MON","Invalid WR preamble. Using 2TCK")

    end
 
  endcase
 
  preamble_samples = 2 * preamble_tck;
 
  if (tr.full_bl32) begin

   case(tr.wr_preamble)

      WR_PRE_2TCK :
         preamble_wait_cycles = `TCWL - 11;

      WR_PRE_3TCK :
         preamble_wait_cycles = `TCWL - 12;

      WR_PRE_4TCK :
         preamble_wait_cycles = `TCWL - 13;

      default :
         preamble_wait_cycles = `TCWL - 11;

   endcase

   dq_wait_cycles = `TCWL - 9;

  end
  else begin

    case(tr.wr_preamble)

      WR_PRE_2TCK :
        preamble_wait_cycles = `TCWL - 2;

      WR_PRE_3TCK :
        preamble_wait_cycles = `TCWL - 3;

      WR_PRE_4TCK :
        preamble_wait_cycles = `TCWL - 4;

      default :
        preamble_wait_cycles = `TCWL - 2;

    endcase

    dq_wait_cycles = `TCWL;

  end 
 
    `uvm_info("WRITE_TIMING",$sformatf("WR_PRE=%0d PRE_WAIT=%0d DQ_WAIT=%0d DATA_WIDTH=%0d",preamble_tck,preamble_wait_cycles,dq_wait_cycles,`DATA_WIDTH),UVM_LOW)
 
  fork
 
    begin : PREAMBLE_THREAD
 
      if (tr.seamless_write) begin

        `uvm_info("WR_PRE",

          "SEAMLESS WRITE: SKIPPING INDEPENDENT PREAMBLE",

          UVM_LOW)

      end

      else begin
 
      repeat (preamble_wait_cycles)

        @(vif.ddr5_mon_cb_t);
 
      for (int i = 0; i < preamble_samples; i++) begin
 
        if ((i % 2) == 0) begin
 
          @(vif.ddr5_mon_pre_t_cb);
 
          if (`DATA_WIDTH == 16) begin
 
            tr.dqsl_t_preamble[i] = vif.ddr5_mon_pre_t_cb.dqsl_t;

            tr.dqsl_c_preamble[i] = vif.ddr5_mon_pre_t_cb.dqsl_c;

            tr.dqsu_t_preamble[i] = vif.ddr5_mon_pre_t_cb.dqsu_t;

            tr.dqsu_c_preamble[i] = vif.ddr5_mon_pre_t_cb.dqsu_c;
 
            `uvm_info("WR_PRE",$sformatf("PREAMBLE[%0d] T : DQSL_T=%0b DQSL_C=%0b DQSU_T=%0b DQSU_C=%0b",i,tr.dqsl_t_preamble[i],tr.dqsl_c_preamble[i],tr.dqsu_t_preamble[i],tr.dqsu_c_preamble[i]),UVM_LOW)
 
          end

          else begin
 
            tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_t;

            tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_c;
 
            `uvm_info("WR_PRE",$sformatf("PREAMBLE[%0d] T : DQS_T=%0b DQS_C=%0b",i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
 
          end
 
        end

        else begin
 
          @(vif.ddr5_mon_pre_c_cb);
 
          if (`DATA_WIDTH == 16) begin
 
            tr.dqsl_t_preamble[i] = vif.ddr5_mon_pre_c_cb.dqsl_t;

            tr.dqsl_c_preamble[i] = vif.ddr5_mon_pre_c_cb.dqsl_c;

            tr.dqsu_t_preamble[i] = vif.ddr5_mon_pre_c_cb.dqsu_t;

            tr.dqsu_c_preamble[i] = vif.ddr5_mon_pre_c_cb.dqsu_c;
 
            `uvm_info("WR_PRE",$sformatf("PREAMBLE[%0d] C : DQSL_T=%0b DQSL_C=%0b DQSU_T=%0b DQSU_C=%0b",i,tr.dqsl_t_preamble[i],tr.dqsl_c_preamble[i],tr.dqsu_t_preamble[i],tr.dqsu_c_preamble[i]),UVM_LOW)
 
          end

          else begin
 
            tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_t;

            tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_c;
 
            `uvm_info("WR_PRE",$sformatf("PREAMBLE[%0d] C : DQS_T=%0b DQS_C=%0b",i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
 
          end
 
        end
 
      end
 
      `uvm_info("WR_PRE","WRITE PREAMBLE COMPLETE",UVM_LOW)
 
      end // non-seamless preamble capture

    end
 
 
    begin : DQ_THREAD
 
      repeat (dq_wait_cycles)

        @(vif.ddr5_mon_cb_t);
 
      `uvm_info("WRITE_DQ","DQ MONITOR THREAD ACTIVE - FIRST DQ SAMPLE POINT REACHED",UVM_LOW)
 
      if (`DATA_WIDTH == 16) begin
 
        @(vif.ddr5_mon_dqsl_t_cb);
 
        tr.dq_burst[0] = vif.ddr5_mon_dqsl_t_cb.dq;
 
        tr.dqsl_t_burst[0] = vif.ddr5_mon_dqsl_t_cb.dqsl_t;

        tr.dqsl_c_burst[0] = vif.ddr5_mon_dqsl_t_cb.dqsl_c;

        tr.dqsu_t_burst[0] = vif.ddr5_mon_dqsl_t_cb.dqsu_t;

        tr.dqsu_c_burst[0] = vif.ddr5_mon_dqsl_t_cb.dqsu_c;
 
        tr.dml_burst[0] = vif.ddr5_mon_dqsl_t_cb.dml_n;

        tr.dmu_burst[0] = vif.ddr5_mon_dqsl_t_cb.dmu_n;
 
        `uvm_info("WRITE_DQ",$sformatf("WRITE[0] DQ=%04h DQSL_T=%0b DQSL_C=%0b DQSU_T=%0b DQSU_C=%0b DML_n=%0b DMU_n=%0b",tr.dq_burst[0],tr.dqsl_t_burst[0],tr.dqsl_c_burst[0],tr.dqsu_t_burst[0],tr.dqsu_c_burst[0],tr.dml_burst[0],tr.dmu_burst[0]),UVM_LOW)
 
        for (int i = 1; i < burst_limit; i++) begin

          int disp_indx;

          disp_indx = i;

          if (tr.bc8_upper_half)
            disp_indx = i + 8;
          else if (tr.bl32_upper_half)
            disp_indx = i + 16;
 
          if ((i % 2) == 1) begin
 
            @(vif.ddr5_mon_dqsl_c_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqsl_c_cb.dq;
 
            tr.dqsl_t_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsl_t;

            tr.dqsl_c_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsl_c;

            tr.dqsu_t_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsu_t;

            tr.dqsu_c_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsu_c;
 
            tr.dml_burst[i] = vif.ddr5_mon_dqsl_c_cb.dml_n;

            tr.dmu_burst[i] = vif.ddr5_mon_dqsl_c_cb.dmu_n;
 
            `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] C | DQ=%04h | DQSL_T=%0b DQSL_C=%0b | DQSU_T=%0b DQSU_C=%0b | DML_n=%0b | DMU_n=%0b",disp_indx,tr.dq_burst[i],tr.dqsl_t_burst[i],tr.dqsl_c_burst[i],tr.dqsu_t_burst[i],tr.dqsu_c_burst[i],tr.dml_burst[i],tr.dmu_burst[i]),UVM_LOW)
 
          end

          else begin
 
            @(vif.ddr5_mon_dqsl_t_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqsl_t_cb.dq;
 
            tr.dqsl_t_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsl_t;

            tr.dqsl_c_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsl_c;

            tr.dqsu_t_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsu_t;

            tr.dqsu_c_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsu_c;
 
            tr.dml_burst[i] = vif.ddr5_mon_dqsl_t_cb.dml_n;

            tr.dmu_burst[i] = vif.ddr5_mon_dqsl_t_cb.dmu_n;
 
            `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] T | DQ=%04h | DQSL_T=%0b DQSL_C=%0b | DQSU_T=%0b DQSU_C=%0b | DML_n=%0b | DMU_n=%0b",disp_indx,tr.dq_burst[i],tr.dqsl_t_burst[i],tr.dqsl_c_burst[i],tr.dqsu_t_burst[i],tr.dqsu_c_burst[i],tr.dml_burst[i],tr.dmu_burst[i]),UVM_LOW)
 
          end
 
        end
 
      end

      else begin
 
        @(vif.ddr5_mon_dqs_t_cb);
 
        tr.dq_burst[0] = vif.ddr5_mon_dqs_t_cb.dq;

        tr.dqs_t_burst[0] = vif.ddr5_mon_dqs_t_cb.dqs_t;

        tr.dqs_c_burst[0] = vif.ddr5_mon_dqs_t_cb.dqs_c;
 
        if (`DATA_WIDTH == 8) begin

          tr.dm_burst[0] = vif.ddr5_mon_dqs_t_cb.dm_n;

          `uvm_info("WRITE_DQ",$sformatf("WRITE[0] DQ=%02h DQS_T=%0b DQS_C=%0b DM_n=%0b",tr.dq_burst[0],tr.dqs_t_burst[0],tr.dqs_c_burst[0],tr.dm_burst[0]),UVM_LOW)

        end

        else begin

          `uvm_info("WRITE_DQ",$sformatf("WRITE[0] DQ=%01h DQS_T=%0b DQS_C=%0b x4 | DM NOT SUPPORTED",tr.dq_burst[0],tr.dqs_t_burst[0],tr.dqs_c_burst[0]),UVM_LOW)

        end
 
        for (int i = 1; i < burst_limit; i++) begin
          
          int disp_indx;

          disp_indx = i;

          if (tr.bc8_upper_half)
            disp_indx = i + 8;
          else if (tr.bl32_upper_half)
            disp_indx = i + 16;
 
          if ((i % 2) == 1) begin
 
            @(vif.ddr5_mon_dqs_c_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqs_c_cb.dq;

            tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_t;

            tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_c;
 
            if (`DATA_WIDTH == 8) begin

              tr.dm_burst[i] = vif.ddr5_mon_dqs_c_cb.dm_n;

              `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] C | DQ=%02h | DQS_T=%0b DQS_C=%0b | DM_n=%0b",disp_indx,tr.dq_burst[i],tr.dqs_t_burst[i],tr.dqs_c_burst[i],tr.dm_burst[i]),UVM_LOW)

            end

            else begin

              `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] C | DQ=%01h | DQS_T=%0b DQS_C=%0b | x4",disp_indx,tr.dq_burst[i],tr.dqs_t_burst[i],tr.dqs_c_burst[i]),UVM_LOW)

            end
 
          end

          else begin
 
            @(vif.ddr5_mon_dqs_t_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqs_t_cb.dq;

            tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_t;

            tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_c;
 
            if (`DATA_WIDTH == 8) begin

              tr.dm_burst[i] = vif.ddr5_mon_dqs_t_cb.dm_n;

              `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] T | DQ=%02h | DQS_T=%0b DQS_C=%0b | DM_n=%0b",disp_indx,tr.dq_burst[i],tr.dqs_t_burst[i],tr.dqs_c_burst[i],tr.dm_burst[i]),UVM_LOW)

            end

            else begin

              `uvm_info("WRITE_DQ",$sformatf("WRITE[%0d] T | DQ=%01h | DQS_T=%0b DQS_C=%0b | x4",disp_indx,tr.dq_burst[i],tr.dqs_t_burst[i],tr.dqs_c_burst[i]),UVM_LOW)

            end
 
          end
 
        end
 
      end
 
    end
 
  join
 
  `uvm_info("WRITE_DQ",$sformatf("ALL %0d WRITE DQ BEATS CAPTURED", burst_limit),UVM_LOW)
 
endtask
 


  // Get READ Preamble Information

  function void get_rd_preamble_info();
 
    rd_preamble_tck = 0;

    rd_preamble_samples = 0;
 
    case (current_rd_preamble)
 
      3'b000: rd_preamble_tck = 1;

      3'b001: rd_preamble_tck = 2;

      3'b010: rd_preamble_tck = 2;

      3'b011: rd_preamble_tck = 3;

      3'b100: rd_preamble_tck = 4;
 
      default: begin

        `uvm_warning("DDR5_MON", $sformatf("Unsupported RD preamble mode=%b", current_rd_preamble))

        rd_preamble_tck = 0;

      end
 
    endcase
 
    rd_preamble_samples = 2 * rd_preamble_tck;
 
  endfunction
 
 
    // Sample READ Preamble + BL16 Data

  task sample_read_data(ddr5_seq_item tr);
 
  int wait_cycles;

  bit read_response_present;

  int burst_limit;

  if (tr.full_bl32)
    burst_limit = 32;
  else if ((tr.bl == BC8_OTF) && (tr.ca5 == 1'b0))
    burst_limit = 8;
  else
    burst_limit = 16;

    `uvm_info("READ_BURST_DEBUG", $sformatf("BL=%s CA5=%0d BURST_LIMIT=%0d",
          tr.bl.name(),
          tr.ca5,
          burst_limit),
        UVM_LOW)
 
  get_rd_preamble_info();
 
  `uvm_info("READ_DEBUG",$sformatf("READ PREAMBLE MODE=%b PREAMBLE=%0d tCK TCL=%0d DATA_WIDTH=%0d",current_rd_preamble,rd_preamble_tck,`TCL,`DATA_WIDTH),UVM_LOW)
 
  wait_cycles = `TCL - rd_preamble_tck;
 
  if (wait_cycles < 0) begin

    `uvm_error("DDR5_MON",$sformatf("Invalid timing: TCL=%0d PREAMBLE=%0d",`TCL,rd_preamble_tck))

    return;

  end
 
  repeat (wait_cycles)

    @(vif.ddr5_mon_cb_t);
 
  for (int i = 0; i < rd_preamble_samples; i++) begin
 
    if ((i % 2) == 0) begin
 
      @(vif.ddr5_mon_cb_t);
 
      if (`DATA_WIDTH == 16) begin
 
        tr.dqsl_t_preamble[i] = vif.ddr5_mon_cb_t.dqsl_t;

        tr.dqsl_c_preamble[i] = vif.ddr5_mon_cb_t.dqsl_c;

        tr.dqsu_t_preamble[i] = vif.ddr5_mon_cb_t.dqsu_t;

        tr.dqsu_c_preamble[i] = vif.ddr5_mon_cb_t.dqsu_c;
 
        `uvm_info("DDR5_MON_RD_PRE",$sformatf("PREAMBLE[%0d] T : DQSL_T=%b DQSL_C=%b DQSU_T=%b DQSU_C=%b",i,tr.dqsl_t_preamble[i],tr.dqsl_c_preamble[i],tr.dqsu_t_preamble[i],tr.dqsu_c_preamble[i]),UVM_LOW)
 
      end

      else begin
 
        tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_t.dqs_t;

        tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_t.dqs_c;
 
        `uvm_info("DDR5_MON_RD_PRE",$sformatf("PREAMBLE[%0d] T : DQS_T=%b DQS_C=%b",i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
 
      end
 
    end

    else begin
 
      @(vif.ddr5_mon_cb_c);
 
      if (`DATA_WIDTH == 16) begin
 
        tr.dqsl_t_preamble[i] = vif.ddr5_mon_cb_c.dqsl_t;

        tr.dqsl_c_preamble[i] = vif.ddr5_mon_cb_c.dqsl_c;

        tr.dqsu_t_preamble[i] = vif.ddr5_mon_cb_c.dqsu_t;

        tr.dqsu_c_preamble[i] = vif.ddr5_mon_cb_c.dqsu_c;
 
        `uvm_info("DDR5_MON_RD_PRE",$sformatf("PREAMBLE[%0d] C : DQSL_T=%b DQSL_C=%b DQSU_T=%b DQSU_C=%b",i,tr.dqsl_t_preamble[i],tr.dqsl_c_preamble[i],tr.dqsu_t_preamble[i],tr.dqsu_c_preamble[i]),UVM_LOW)
 
      end

      else begin
 
        tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_c.dqs_t;

        tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_c.dqs_c;
 
        `uvm_info("DDR5_MON_RD_PRE",$sformatf("PREAMBLE[%0d] C : DQS_T=%b DQS_C=%b",i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
 
      end
 
    end
 
  end
 
  read_response_present = 1'b1;
 
  if (`DATA_WIDTH == 16) begin
 
    for (int i = 0; i < rd_preamble_samples; i++) begin
 
      if ((tr.dqsl_t_preamble[i] !== 1'b0 && tr.dqsl_t_preamble[i] !== 1'b1) ||

          (tr.dqsl_c_preamble[i] !== 1'b0 && tr.dqsl_c_preamble[i] !== 1'b1) ||

          (tr.dqsu_t_preamble[i] !== 1'b0 && tr.dqsu_t_preamble[i] !== 1'b1) ||

          (tr.dqsu_c_preamble[i] !== 1'b0 && tr.dqsu_c_preamble[i] !== 1'b1)) begin
 
        read_response_present = 1'b0;

        break;
 
      end
 
    end
 
  end

  else begin
 
    for (int i = 0; i < rd_preamble_samples; i++) begin
 
      if ((tr.dqs_t_preamble[i] !== 1'b0 && tr.dqs_t_preamble[i] !== 1'b1) ||

          (tr.dqs_c_preamble[i] !== 1'b0 && tr.dqs_c_preamble[i] !== 1'b1)) begin
 
        read_response_present = 1'b0;

        break;
 
      end
 
    end
 
  end
 
  if (!read_response_present) begin
 
    `uvm_info("DDR5_MON","NO READ DATA STROBE DETECTED - FILLING ALL 16 READ BEATS WITH X",UVM_LOW)
 
    for (int i = 0; i < burst_limit; i++) begin
      
      int disp_indx;

      disp_indx = i;

      if (tr.bc8_upper_half)
        disp_indx = i + 8;
      else if (tr.bl32_upper_half)
        disp_indx = i + 16;

      tr.dq_burst[i] = 'x;

      tr.dqs_t_burst[i] = 1'bx;

      tr.dqs_c_burst[i] = 1'bx;
 
      tr.dqsl_t_burst[i] = 1'bx;

      tr.dqsl_c_burst[i] = 1'bx;

      tr.dqsu_t_burst[i] = 1'bx;

      tr.dqsu_c_burst[i] = 1'bx;
 
      tr.dml_burst[i] = 1'bx;

      tr.dmu_burst[i] = 1'bx;

      tr.dm_burst[i] = 1'bx;
 
      `uvm_info("DDR5_MON",$sformatf("READ[%0d] NO RESPONSE -> DQ=X",disp_indx),UVM_LOW)
 
    end
 
  end

  else begin
 
    `uvm_info("DDR5_MON","READ DATA STROBE DETECTED - STARTING BL16 DATA SAMPLING",UVM_LOW)
 
    if (`DATA_WIDTH == 16) begin
 
      for (int i = 0; i < burst_limit; i++) begin

        int disp_indx;

        disp_indx = i;

        if (tr.bc8_upper_half)
          disp_indx = i + 8;
        else if (tr.bl32_upper_half)
          disp_indx = i + 16;
 
        if ((i % 2) == 0) begin
 
          @(vif.ddr5_mon_dqsl_t_cb);
 
          tr.dq_burst[i] = vif.ddr5_mon_dqsl_t_cb.dq;

          tr.dqsl_t_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsl_t;

          tr.dqsl_c_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsl_c;

          tr.dqsu_t_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsu_t;

          tr.dqsu_c_burst[i] = vif.ddr5_mon_dqsl_t_cb.dqsu_c;
 
          tr.dml_burst[i] = vif.ddr5_mon_dqsl_t_cb.dml_n;

          tr.dmu_burst[i] = vif.ddr5_mon_dqsl_t_cb.dmu_n;
 
        end

        else begin
 
          @(vif.ddr5_mon_dqsl_c_cb);
 
          tr.dq_burst[i] = vif.ddr5_mon_dqsl_c_cb.dq;

          tr.dqsl_t_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsl_t;

          tr.dqsl_c_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsl_c;

          tr.dqsu_t_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsu_t;

          tr.dqsu_c_burst[i] = vif.ddr5_mon_dqsl_c_cb.dqsu_c;
 
          tr.dml_burst[i] = vif.ddr5_mon_dqsl_c_cb.dml_n;

          tr.dmu_burst[i] = vif.ddr5_mon_dqsl_c_cb.dmu_n;
 
        end
 
        `uvm_info("DDR5_MON_READ_DQ",$sformatf("READ[%0d] DQ=%04h DQSL_T=%b DQSL_C=%b DQSU_T=%b DQSU_C=%b DML_n=%b DMU_n=%b",disp_indx,tr.dq_burst[i],tr.dqsl_t_burst[i],tr.dqsl_c_burst[i],tr.dqsu_t_burst[i],tr.dqsu_c_burst[i],tr.dml_burst[i],tr.dmu_burst[i]),UVM_LOW)
 
      end
 
    end

    else begin
 
      for (int i = 0; i < burst_limit; i++) begin

        int disp_indx;

        disp_indx = i;

        if (tr.bc8_upper_half)
          disp_indx = i + 8;
        else if (tr.bl32_upper_half)
          disp_indx = i + 16;
 
        if ((i % 2) == 0) begin
 
          @(vif.ddr5_mon_dqs_t_cb);
 
          tr.dq_burst[i] = vif.ddr5_mon_dqs_t_cb.dq;

          tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_t;

          tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_c;
 
          if (`DATA_WIDTH == 8)

            tr.dm_burst[i] = vif.ddr5_mon_dqs_t_cb.dm_n;
 
        end

        else begin
 
          @(vif.ddr5_mon_dqs_c_cb);
 
          tr.dq_burst[i] = vif.ddr5_mon_dqs_c_cb.dq;

          tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_t;

          tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_c;
 
          if (`DATA_WIDTH == 8)

            tr.dm_burst[i] = vif.ddr5_mon_dqs_c_cb.dm_n;
 
        end
 
        `uvm_info("DDR5_MON_READ_DQ",$sformatf("READ[%0d] DQ=%0h DQS_T=%b DQS_C=%b",disp_indx,tr.dq_burst[i],tr.dqs_t_burst[i],tr.dqs_c_burst[i]),UVM_LOW)
 
      end
 
    end
 
  end
 
  `uvm_info("READ_DEBUG","READ PREAMBLE CHECK AND RESPONSE CAPTURE COMPLETE",UVM_LOW)
 
endtask
 
endclass : ddr5_monitor
 
 
 



class ddr5_wr_rd_without_act_seq_x8 extends uvm_sequence #(ddr5_seq_item);

  `uvm_object_utils(ddr5_wr_rd_without_act_seq_x8)

  ddr5_seq_item seq;

  rand bit [`BG_WIDTH-1:0]  target_bg;
  rand bit [`BA_WIDTH-1:0]  target_ba;
  rand bit [`ROW_WIDTH-1:0] target_row;
  rand bit [`COL_WIDTH-1:0] target_col;

  bit [`COL_WIDTH-1:0] col_addr[$];
  bit [`COL_WIDTH-1:0] pop_addr;

  function new(string name = "ddr5_wr_rd_without_act_seq_x8");
    super.new(name);
  endfunction

  task body();

    seq = ddr5_seq_item::type_id::create("seq");

    `uvm_info("SEQ", "Generating WRITE/READ without ACTIVATE negative testcase", UVM_LOW)

    // MRW
    start_item(seq);

    if (!seq.randomize() with {
      cmd == MRW;
      bl == BL16;
      rl == RL22;
      wr_preamble == WR_PRE_4TCK;
      wr_postamble == WR_PSTBLE_1_5TCK;
    })
      `uvm_error("SEQ_MRW", "Randomization failed")

    finish_item(seq);

    // Random address
    if (!this.randomize() with {
      target_col[2:0] == 3'b000;
    })
      `uvm_error("SEQ_RAND", "Address randomization failed")

    `uvm_info("SEQ_RAND",
      $sformatf("BG=%0d BA=%0d ROW=%0d COL=%0d",
                target_bg, target_ba, target_row, target_col),
      UVM_LOW)

    // ACTIVATE - OPEN BANK
    start_item(seq);

    if (!seq.randomize() with {
      cmd == ACTIVATE;
      bg == target_bg;
      ba == target_ba;
      row == target_row;
      reset_n == 1'b1;
    })
      `uvm_error("SEQ_ACTIVATE", "Randomization failed")

    finish_item(seq);

    // FIRST WRITE - LEGAL
    start_item(seq);

    if (!seq.randomize() with {
      cmd == WRITE;
      bl == BL16;
      bg == target_bg;
      ba == target_ba;
      col == target_col;
      ap_n == 1'b1;
      reset_n == 1'b1;
      foreach (dm_burst[i])
        dm_burst[i] == 1'b1;
    })
      `uvm_error("SEQ_WRITE", "Randomization failed")

    col_addr.push_back(seq.col);

    finish_item(seq);

    `uvm_info("SEQ_WRITE",
      $sformatf("LEGAL WRITE BG=%0d BA=%0d COL=%0d",
                seq.bg, seq.ba, seq.col),
      UVM_LOW)

    // FIRST READ - LEGAL
    if (col_addr.size() > 0) begin

      pop_addr = col_addr.pop_front();

      start_item(seq);

      if (!seq.randomize() with {
        cmd == READ;
        bl == BL16;
        rl == RL22;
        bg == target_bg;
        ba == target_ba;
        col == pop_addr;
        ap_n == 1'b1;
        reset_n == 1'b1;
      })
        `uvm_error("SEQ_READ", "Randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_READ",
        $sformatf("LEGAL READ BG=%0d BA=%0d COL=%0d",
                  seq.bg, seq.ba, seq.col),
        UVM_LOW)
    end

    // Allow legal READ response window and bank timing to complete.
    // This assumes the effective time unit is ns, tCK = 0.625 ns,
    // RL = 22 CK, BL16 = 8 CK, plus guard time.
    // Replace with configured timing/synchronization if different.
   // #25ns;

    // PRECHARGE SAME BANK
    start_item(seq);

    if (!seq.randomize() with {
      cmd == PRECHARGE;
      bg == target_bg;
      ba == target_ba;
      reset_n == 1'b1;
    })
      `uvm_error("SEQ_PRE", "Randomization failed")

    finish_item(seq);

    `uvm_info("SEQ_PRE",
      $sformatf("PRECHARGE BG=%0d BA=%0d - BANK CLOSED",
                target_bg, target_ba),
      UVM_LOW)
 start_item(seq);
//2nd actt
    if (!seq.randomize() with {
      cmd == ACTIVATE;
      bg == target_bg;
      ba == target_ba;
      row == target_row;
      reset_n == 1'b1;
    })
      `uvm_error("SEQ_ACTIVATE", "Randomization failed")

    finish_item(seq);

    // NEGATIVE WRITE - WITHOUT ACTIVATE
    start_item(seq);

    if (!seq.randomize() with {
      cmd == WRITE;
      bl == BL16;
      bg == target_bg;
      ba == target_ba;
      col == target_col;
      ap_n == 1'b1;
      reset_n == 1'b1;
      foreach (dm_burst[i])
        dm_burst[i] == 1'b1;
    })
      `uvm_error("SEQ_WRITE", "Randomization failed")

    col_addr.push_back(seq.col);

    finish_item(seq);

    `uvm_info("SEQ_WRITE",
      $sformatf("NEGATIVE WRITE WITHOUT ACTIVATE BG=%0d BA=%0d COL=%0d",
                seq.bg, seq.ba, seq.col),
      UVM_LOW)

    // NEGATIVE READ - WITHOUT ACTIVATE
    if (col_addr.size() > 0) begin

      pop_addr = col_addr.pop_front();

      start_item(seq);

      if (!seq.randomize() with {
        cmd == READ;
        bl == BL16;
        rl == RL22;
        bg == target_bg;
        ba == target_ba;
        col == pop_addr;
        ap_n == 1'b1;
        reset_n == 1'b1;
      })
        `uvm_error("SEQ_READ", "Randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_READ",
        $sformatf("NEGATIVE READ WITHOUT ACTIVATE BG=%0d BA=%0d COL=%0d",
                  seq.bg, seq.ba, seq.col),
        UVM_LOW)
    end

  endtask

endclass


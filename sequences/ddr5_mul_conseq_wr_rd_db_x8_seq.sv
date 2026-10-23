
class ddr5_mul_conseq_wr_rd_db_x8_seq extends uvm_sequence #(ddr5_seq_item);

  `uvm_object_utils(ddr5_mul_conseq_wr_rd_db_x8_seq)

  ddr5_seq_item seq;

  rand bit [`BG_WIDTH-1:0]  target_bg;
  rand bit [`BA_WIDTH-1:0]  target_ba;
  rand bit [`ROW_WIDTH-1:0] target_row;
  rand bit [`COL_WIDTH-1:0] target_col;

  rand int num;

  constraint counts {
    num inside {[2:3]};
  }

  typedef struct {
    bit [`BG_WIDTH-1:0]  bg;
    bit [`BA_WIDTH-1:0]  ba;
    bit [`ROW_WIDTH-1:0] row;
    bit [`COL_WIDTH-1:0] col;
  } addr_t;

  addr_t addr_q[$];

  function new(string name = "ddr5_mul_conseq_wr_rd_db_x8_seq");
    super.new(name);
  endfunction

  task body();

    seq = ddr5_seq_item::type_id::create("seq");

    addr_q.delete();

    `uvm_info("SEQ",
      "Starting different-BG consecutive WRITE/READ sequence",
      UVM_LOW)

    // MRW
    start_item(seq);

    if (!seq.randomize() with {
      cmd == MRW;
      bl == BL16;
      rl == RL22;
      wr_preamble == WR_PRE_4TCK;
      wr_postamble == WR_PSTBLE_0_5TCK;
    })
      `uvm_fatal("SEQ_MRW", "MRW randomization failed")

    finish_item(seq);

    if (!this.randomize() with {
      target_col[2:0] == 3'b000;
     // target_col <= ((1 << `COL_WIDTH) - 1 - 48);
    })
      `uvm_fatal("SEQ_RAND", "Sequence randomization failed")

    `uvm_info("SEQ",
      $sformatf("Number of WRITE/READ transactions = %0d", num),
      UVM_LOW)

    //=========================================================
    // 1. ACTIVATE AND SAVE ADDRESSES
    //=========================================================

    repeat(num) begin

      // Current BG must differ from all previously selected BGs.
      if (!this.randomize(target_bg) with {
        foreach (addr_q[j])
          target_bg != addr_q[j].bg;
      })
        `uvm_fatal("SEQ_ADDR", "Different-BG randomization failed")

      addr_q.push_back('{
        bg  : target_bg,
        ba  : target_ba,
        row : target_row,
        col : target_col + (addr_q.size() * 16)
      });

      start_item(seq);

      if (!seq.randomize() with {
        cmd == ACTIVATE;
        bg  == target_bg;
        ba  == target_ba;
        row == target_row;
      })
        `uvm_fatal("SEQ_ACT", "ACTIVATE randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_ACT",
        $sformatf("ACTIVATE -> BG=%0d BA=%0d ROW=%0d",
                  target_bg, target_ba, target_row),
        UVM_LOW)

    end

    //=========================================================
    // 2. WRITE TO SAVED ADDRESSES
    //=========================================================

    foreach (addr_q[i]) begin

      start_item(seq);

      if (!seq.randomize() with {
        cmd == WRITE;
        bl  == BL16;
        bg  == addr_q[i].bg;
        ba  == addr_q[i].ba;
        col == addr_q[i].col;
	ap_n==1'b1;
	foreach (dm_burst[i])
		dm_burst[i]==1;
      })
        `uvm_fatal("SEQ_WR", "WRITE randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_WR",
        $sformatf("WRITE%0d -> BG=%0d BA=%0d ROW=%0d COL=%0d",
                  i+1,
                  addr_q[i].bg,
                  addr_q[i].ba,
                  addr_q[i].row,
                  addr_q[i].col),
        UVM_LOW)

    end

    //=========================================================
    // 3. READ FROM SAVED ADDRESSES
    //=========================================================

    repeat(num) begin

      start_item(seq);

      if (!seq.randomize() with {
        cmd == READ;
        bl  == BL16;
        rl  == RL22;
        bg  == addr_q[0].bg;
        ba  == addr_q[0].ba;
        col == addr_q[0].col;
	ap_n==1'b1;
      })
        `uvm_fatal("SEQ_RD", "READ randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_RD",
        $sformatf("READ -> BG=%0d BA=%0d ROW=%0d COL=%0d",
                  addr_q[0].bg,
                  addr_q[0].ba,
                  addr_q[0].row,
                  addr_q[0].col),
        UVM_LOW)

      addr_q.pop_front();

    end

  endtask

endclass

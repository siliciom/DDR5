class ddr5_mul_nonconseq_wr_rd_sb_x8_seq extends uvm_sequence #(ddr5_seq_item);

  `uvm_object_utils(ddr5_mul_nonconseq_wr_rd_sb_x8_seq)

  ddr5_seq_item seq;

  rand bit [`BG_WIDTH-1:0]  target_bg;
  rand bit [`BA_WIDTH-1:0]  target_ba;
  rand bit [`ROW_WIDTH-1:0] target_row;
  rand bit [`COL_WIDTH-1:0] target_col;

  rand int num;

  constraint counts {
    // num inside {[1:3]};
    num == 3;
  }

  typedef struct {
    bit [`BG_WIDTH-1:0]  bg;
    bit [`BA_WIDTH-1:0]  ba;
    bit [`ROW_WIDTH-1:0] row;
    bit [`COL_WIDTH-1:0] col;
  } addr_t;

  addr_t addr_q[$];

  function new(string name = "ddr5_mul_nonconseq_wr_rd_sb_x8_seq");
    super.new(name);
  endfunction

  task body();

    seq = ddr5_seq_item::type_id::create("seq");

    addr_q.delete();

    `uvm_info("SEQ", "Generating transaction", UVM_LOW)

    //=========================================================
    // 0. MODE REGISTER CONFIGURATION
    //=========================================================

    start_item(seq);

    if (!seq.randomize() with {
      cmd           == MRW;
      bl            == BL16;
      rl            == RL22;
      wr_preamble   == WR_PRE_3TCK;
      wr_postamble  == WR_PSTBLE_1_5TCK;
    })
      `uvm_fatal("SEQ_MRW", "MRW randomization failed")

    finish_item(seq);

    `uvm_info("SEQ_MRW",
      "MRW configured: BL16 RL22 WR_PRE_2TCK WR_PSTBLE_1_5TCK",
      UVM_LOW)

    // Randomize BG and num once.
    if (!this.randomize())
      `uvm_error("SEQ_RAND", "Sequence body randomization failed")

    //=========================================================
    // 1. GENERATE ALL ADDRESSES + ACTIVATE FIRST
    //=========================================================

    repeat(num) begin

      // Randomize BA, ROW, COL only.
      // Keep the same BG and use different BA values.
      if (!this.randomize(target_ba,
                          target_row, target_col) with {
        target_col[2:0] == 3'b000;

        foreach (addr_q[j])
          target_ba != addr_q[j].ba;
      })
        `uvm_error("SEQ_ADDR", "Address randomization failed")

      addr_q.push_back('{
        bg  : target_bg,
        ba  : target_ba,
        row : target_row,
        col : target_col
      });

      // ACTIVATE
      start_item(seq);

      if (!seq.randomize() with {
        cmd == ACTIVATE;
        bg  == target_bg;
        ba  == target_ba;
        row == target_row;
      })
        `uvm_error("SEQ_ACT", "Randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_ACT",
        $sformatf("ACTIVATE -> BG=%0d BA=%0d ROW=%0d",
                  target_bg, target_ba, target_row), UVM_LOW)

    end

    //=========================================================
    // 2. WRITE TO THE SAME ADDRESSES
    //=========================================================

    foreach (addr_q[i]) begin

      start_item(seq);

      if (!seq.randomize() with {
        cmd == WRITE;
        bl  == BL16;
        bg  == addr_q[i].bg;
        ba  == addr_q[i].ba;
        col == addr_q[i].col;
      })
        `uvm_error("SEQ_WR", "Randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_WR",
        $sformatf("WRITE -> BG=%0d BA=%0d ROW=%0d COL=%0d",
                  addr_q[i].bg,
                  addr_q[i].ba,
                  addr_q[i].row,
                  addr_q[i].col), UVM_LOW)

    end

    //=========================================================
    // 3. READ FROM THE SAME ADDRESSES
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
      })
        `uvm_error("SEQ_RD", "Randomization failed")

      finish_item(seq);

      `uvm_info("SEQ_RD",
        $sformatf("READ -> BG=%0d BA=%0d ROW=%0d COL=%0d",
                  addr_q[0].bg,
                  addr_q[0].ba,
                  addr_q[0].row,
                  addr_q[0].col), UVM_LOW)

      addr_q.pop_front();

    end

  endtask

endclass

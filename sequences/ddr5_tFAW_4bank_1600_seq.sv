class ddr5_tFAW_4bank_1600_seq extends uvm_sequence #(ddr5_seq_item);
 
  `uvm_object_utils(ddr5_tFAW_4bank_1600_seq)
 
  ddr5_seq_item seq;
 
  randc bit [`BG_WIDTH-1:0]  target_bg;

  rand bit [`BA_WIDTH-1:0]  target_ba;

  rand bit [`ROW_WIDTH-1:0] target_row;

  rand bit [`COL_WIDTH-1:0] target_col;
 
  bit [`COL_WIDTH-1:0] col_addr[$];

  bit [`COL_WIDTH-1:0] pop_addr;
 
  function new(string name = "ddr5_tFAW_4bank_1600_seq");

    super.new(name);

  endfunction
 
  task body();
 
    seq = ddr5_seq_item::type_id::create("seq");
 
    `uvm_info("SEQ", "Generating transaction", UVM_LOW)

// mrw

    start_item(seq);

    if (!seq.randomize() with {cmd == MRW; bl == BL16; rl == RL22; wr_preamble == WR_PRE_4TCK; wr_postamble == WR_PSTBLE_1_5TCK;})

      `uvm_error("SEQ_MRW", "Randomization failed")

    finish_item(seq);
 
    `uvm_info("SEQ_MRW", $sformatf("MRW -> BL=%s RL=%s WR_PRE=%s WR_POST=%s", seq.bl.name(), seq.rl.name(), seq.wr_preamble.name(), seq.wr_postamble.name()), UVM_LOW)

//randomization

   repeat(4)begin

    if (!this.randomize() with {target_col[2:0] == 3'b000;})

      `uvm_error("SEQ_RAND", "Address randomization failed")
 
    `uvm_info("SEQ_RAND", $sformatf("RANDOM_ADDR -> BG=%0d BA=%0d ROW=%0d COL=%0d", target_bg, target_ba, target_row, target_col), UVM_LOW)

//activate 

    start_item(seq);

    if (!seq.randomize() with {cmd == ACTIVATE; bg == target_bg; ba == target_ba; row == target_row;})

      `uvm_error("SEQ_ACTIVATE", "Randomization failed")
     seq.faw_test = 2;

    finish_item(seq);
 
    `uvm_info("SEQ_ACTIVATE", $sformatf("ACTIVATE -> BG=%0d BA=%0d ROW=%0d", seq.bg, seq.ba, seq.row), UVM_LOW)
    //end

//write 
    //repeat(4)begin
    start_item(seq);

    if (!seq.randomize() with {cmd == WRITE; bl == BL16; bg == target_bg; ba == target_ba; col == target_col;})

      `uvm_error("SEQ_WRITE", "Randomization failed")
 
    col_addr.push_back(seq.col);
 
    finish_item(seq);
 
    `uvm_info("SEQ_WRITE", $sformatf("WRITE -> BG=%0d BA=%0d ROW=%0d COL=%0d BL=%s", seq.bg, seq.ba, target_row, seq.col, seq.bl.name()), UVM_LOW)

//read

    if (col_addr.size() > 0) begin
 
     start_item(seq);

pop_addr = col_addr.pop_front();
 
if (!seq.randomize() with {cmd == READ; bl == BL16; rl == RL22; bg == target_bg; ba == target_ba; col == pop_addr;})

  `uvm_error("SEQ_READ", "Randomization failed")
 
finish_item(seq);
 
`uvm_info("SEQ_READ", $sformatf("READ -> BG=%0d BA=%0d COL=%0d BL=%s RL=%s", seq.bg, seq.ba, seq.col, seq.bl.name(), seq.rl.name()), UVM_LOW)

    end

    else begin

      `uvm_error("SEQ_READ", "Address queue is empty")

    end
 
    end
  endtask
 
endclass

/*class ddr5_tFAW_4bank_1600_seq extends uvm_sequence #(ddr5_seq_item);
  `uvm_object_utils(ddr5_tFAW_4bank_1600_seq)

  ddr5_seq_item seq;

  randc bit [`BG_WIDTH-1:0]  target_bg;
  rand  bit [`BA_WIDTH-1:0]  target_ba;
  rand  bit [`ROW_WIDTH-1:0] target_row;
  rand  bit [`COL_WIDTH-1:0] target_col;

  bit [`BG_WIDTH-1:0]  bg_addr[4];
  bit [`BA_WIDTH-1:0]  ba_addr[4];
  bit [`ROW_WIDTH-1:0] row_addr[4];
  bit [`COL_WIDTH-1:0] col_addr[4];

  function new(string name = "ddr5_tFAW_4bank_1600_seq");
    super.new(name);
  endfunction

  task body();
    seq = ddr5_seq_item::type_id::create("seq");

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

    // 4 ACTIVATEs
    for (int i = 0; i < 4; i++) begin
      if (!this.randomize() with {target_col[2:0] == 3'b000;})
        `uvm_error("SEQ_RAND", "Address randomization failed")

      bg_addr[i]  = target_bg;
      ba_addr[i]  = target_ba;
      row_addr[i] = target_row;
      col_addr[i] = target_col;

      start_item(seq);
      if (!seq.randomize() with {
        cmd == ACTIVATE;
        bg == target_bg;
        ba == target_ba;
        row == target_row;
      })
        `uvm_error("SEQ_ACTIVATE", "Randomization failed")

      seq.faw_test = 2;
      finish_item(seq);
    end

    // WRITE + READ for opened banks
    for (int i = 0; i < 4; i++) begin

      start_item(seq);
      if (!seq.randomize() with {
        cmd == WRITE;
        bl == BL16;
        bg == bg_addr[i];
        ba == ba_addr[i];
        col == col_addr[i];
      })
        `uvm_error("SEQ_WRITE", "Randomization failed")
      finish_item(seq);

      start_item(seq);
      if (!seq.randomize() with {
        cmd == READ;
        bl == BL16;
        rl == RL22;
        bg == bg_addr[i];
        ba == ba_addr[i];
        col == col_addr[i];
      })
        `uvm_error("SEQ_READ", "Randomization failed")
      finish_item(seq);

    end
  endtask
endclass*/

 

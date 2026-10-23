class ddr5_wr_rd_seq_x16 extends uvm_sequence #(ddr5_seq_item);

  `uvm_object_utils(ddr5_wr_rd_seq_x16)

  ddr5_seq_item seq;

  rand bit [`BG_WIDTH-1:0]  target_bg;
 
  rand bit [`BA_WIDTH-1:0]  target_ba;
 
  rand bit [`ROW_WIDTH-1:0] target_row;
 
  rand bit [`COL_WIDTH-1:0] target_col;

  bit [`COL_WIDTH-1:0] col_addr[$];
 
  bit [`COL_WIDTH-1:0] pop_addr;
 
  
 


  function new(string name = "ddr5_wr_rd_seq_x16");
 
    super.new(name);
 
  endfunction

  task body();

    seq = ddr5_seq_item::type_id::create("seq");
 
    

    `uvm_info("SEQ", "Generating transaction Write_Read_x16", UVM_LOW)
 
//mrw
 
    start_item(seq);
 
    if (!seq.randomize() with {cmd == MRW; bl == BL16; rl == RL22; wr_preamble == WR_PRE_4TCK; wr_postamble == WR_PSTBLE_0_5TCK;})
 
      `uvm_error("SEQ_MRW", "Randomization failed")
 
    finish_item(seq);

    `uvm_info("SEQ_MRW", $sformatf("MRW -> BL=%s RL=%s WR_PRE=%s WR_POST=%s", seq.bl.name(), seq.rl.name(), seq.wr_preamble.name(), seq.wr_postamble.name()), UVM_LOW)

    if (!this.randomize() with {target_col[2:0] == 3'b000;})
 
      `uvm_error("SEQ_RAND", "Address randomization failed")

    `uvm_info("SEQ_RAND", $sformatf("RANDOM_ADDR -> BG=%0d BA=%0d ROW=%0d COL=%0d", target_bg, target_ba, target_row, target_col), UVM_LOW)
 
//activate
 
    start_item(seq);
 
    if (!seq.randomize() with {cmd == ACTIVATE; bg == target_bg; ba == target_ba; row == target_row;})
 
      `uvm_error("SEQ_ACTIVATE", "Randomization failed")
 
    finish_item(seq);

    `uvm_info("SEQ_ACTIVATE", $sformatf("ACTIVATE -> BG=%0d BA=%0d ROW=%0d", seq.bg, seq.ba, seq.row), UVM_LOW)
 
// write
 
    start_item(seq);
 
    if (!seq.randomize() with {cmd == WRITE; bl == BL16; bg == target_bg; ba == target_ba; col == target_col; seq.ap_n == 1'b1; foreach(dml_burst[i])

    dml_burst[i] == ((i % 2) == 1);
 
    foreach(dmu_burst[i])

    dmu_burst[i] == ((i % 2) == 1);

    })
 
      `uvm_error("SEQ_WRITE", "Randomization failed")

    col_addr.push_back(seq.col);

    finish_item(seq);

    `uvm_info("SEQ_WRITE", $sformatf("WRITE -> BG=%0d BA=%0d ROW=%0d COL=%0d BL=%s", seq.bg, seq.ba, target_row, seq.col, seq.bl.name()), UVM_LOW)
 
//read
 
    if (col_addr.size() > 0) begin

     start_item(seq);
 
pop_addr = col_addr.pop_front();

if (!seq.randomize() with {cmd == READ_AP; bl == BL16; rl == RL22; bg == target_bg; ba == target_ba; col == pop_addr;seq.ap_n == 1'b0;})
 
  `uvm_error("SEQ_READ", "Randomization failed")

finish_item(seq);

`uvm_info("SEQ_READ", $sformatf("READ -> BG=%0d BA=%0d COL=%0d BL=%s RL=%s", seq.bg, seq.ba, seq.col, seq.bl.name(), seq.rl.name()), UVM_LOW)
 
    end
 
    else begin
 
      `uvm_error("SEQ_READ", "Address queue is empty")
 
    end

  endtask

endclass

 

class ddr5_seq extends uvm_sequence #(ddr5_seq_item);

  `uvm_object_utils(ddr5_seq)

  ddr5_seq_item seq;

  function new(string name="ddr5_seq");
    super.new(name);
  endfunction

   task body();

    seq = ddr5_seq_item::type_id::create("seq");
    `uvm_info("SEQ","Generating transaction",UVM_LOW)

  //MRW 
    start_item(seq);
    if(!seq.randomize with {cmd == MRW; bl == BL16; rl == RL22;wr_preamble == WR_PRE_2TCK; wr_postamble == WR_PSTBLE_1_5TCK;})
	    `uvm_error("SEQ_MRW","random failed")
    finish_item(seq);
      `uvm_info("SEQ_MRW", $sformatf("MRW_SEQ bl %0d rl %0d", seq.bl, seq.rl), UVM_LOW)

 //Activate     
      start_item(seq);
    if(!seq.randomize with {cmd == ACTIVATE; bg == 1; ba == 2; row == 30;})
	    `uvm_error("SEQ_ACTIVATE","random failed")
    finish_item(seq);
      `uvm_info("SEQ_ACTIVATE", $sformatf("MRW_SEQ bg %0d ba %0d row %0d", seq.bg,seq.ba,seq.row), UVM_LOW)

    // WRITE
      start_item(seq);
// if(!seq.randomize with {cmd == WRITE; bl== BL16;bg == 1; ba == 2; col == 12;})
 if(!seq.randomize with {cmd == WRITE; bl== BL16;bg == 1; ba == 2; col == 16;})


	    `uvm_error("SEQ_WRITE","random failed")
    finish_item(seq);
   `uvm_info("SEQ_WRITE", $sformatf("MRW_SEQ bg %0d bl %0d ba %0d col %0d WR_PRE=%0d WR_POST=%0d", seq.bg,seq.bl,seq.ba,seq.col,seq.wr_preamble,
                    seq.wr_postamble), UVM_LOW)
 
    // READ
    start_item(seq);
    if(!seq.randomize with {cmd == READ; bl== BL16; bg == 1; ba == 2; col == 16; })
	    `uvm_error("SEQ_READ","random failed")
    finish_item(seq);
      `uvm_info("SEQ_READ", $sformatf("MRW_SEQ bg %0d ba %0d col %0d", seq.bg,seq.ba,seq.col), UVM_LOW) 

  endtask

endclass

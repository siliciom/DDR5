class ddr5_wr_bl16_otf_bc8_1600_seq extends uvm_sequence #(ddr5_seq_item);
	
	`uvm_object_utils(ddr5_wr_bl16_otf_bc8_1600_seq)

	ddr5_seq_item seq;


	rand bit [`BG_WIDTH-1:0]  target_bg;
  	rand bit [`BA_WIDTH-1:0]  target_ba;
  	rand bit [`ROW_WIDTH-1:0] target_row;
  	rand bit [`COL_WIDTH-1:0] target_col;
 
  	bit [`COL_WIDTH-1:0] col_addr[$];
  	bit [`COL_WIDTH-1:0] pop_addr;

	function new(string name = "ddr5_wr_bl16_otf_bc8_1600_seq");
		super.new(name);
	endfunction

	task body();
		
		seq=ddr5_seq_item::type_id::create("seq");
		`uvm_info("SEQ", "GENERATING TRANSACTION", UVM_LOW)

		// 1. MRW - Configure BC8 OTF
		start_item(seq);
		if(!seq.randomize() with {cmd == MRW; bl == BC8_OTF; rl == RL22; wr_preamble == WR_PRE_2TCK; wr_postamble == WR_PSTBLE_1_5TCK;})
			`uvm_error("SEQ_MRW", "MRW RANDOMIZATION FAILED")
		finish_item(seq);

		`uvm_info("SEQ_MRW", $sformatf("MRW -> BL=%s RL=%s WR_PRE=%s WR_POST=%s", seq.bl.name(), seq.rl.name(), seq.wr_preamble.name(), seq.wr_postamble.name()), UVM_LOW)

//randomization
    if (!this.randomize() with {target_col[3] == 1'b1; target_col[2:0] ==  3'b000;})
      `uvm_error("SEQ_RAND", "Address randomization failed")

      
    `uvm_info("SEQ_RAND", $sformatf(" BC8 RANDOM_ADDR -> BG=%0d BA=%0d ROW=%0d TARGET_COL=%0d C3=%0d", target_bg, target_ba, target_row, target_col, target_col[3]), UVM_LOW)

    		// 2. ACTIVATE 
		start_item(seq);
		if(!seq.randomize() with {cmd == ACTIVATE; bg == target_bg; ba == target_ba; row == target_row;})
			`uvm_error("SEQ_ACTIVATE", "ACTIVATE RANDOMIZATION FAILED")
		finish_item(seq);

		`uvm_info("SEQ_ACTIVATE",$sformatf("ACTIVATE BG %0d BA %0d ROW %0d", seq.bg, seq.ba, seq.row),UVM_LOW)

		// 3. WRITE - BC8 OTF
		start_item(seq);
		if(!seq.randomize() with {cmd == WRITE; bl == BC8_OTF; bg == target_bg; ba == target_ba; col == target_col; ca5 == 0;})
			`uvm_error("SEQ_WRITE", "BC8 WRITE RANDOMIZATION FAILED")

		`uvm_info("SEQ_DEBUG",
  $sformatf("BEFORE finish_item: target_col=%0d seq.col=%0d seq.ca5=%0d",target_col, seq.col, seq.ca5),UVM_LOW)
		

		col_addr.push_back(seq.col);

		finish_item(seq);

		`uvm_info("SEQ_WRITE", $sformatf("BC8 OTF WRITE  BL=%s CA5=%0d COL=%0d C3=%0d", seq.bl.name(), seq.ca5, seq.col, seq.col[3]), UVM_LOW)
		

		// 4. READ - BC8 OTF
		if(col_addr.size() > 0) begin

		start_item(seq);

		pop_addr = col_addr.pop_front();

		if(!seq.randomize() with {cmd == READ; bl == BC8_OTF; bg == target_bg; ba == target_ba; col == pop_addr; ca5 == 0;})
			`uvm_error("SEQ_READ", "BC8 READ RANDOMIZATION FAILED")
		finish_item(seq);

		
		`uvm_info("SEQ_READ", $sformatf("BC8 OTF READ  BL=%s CA5=%0d COL=%0d C3=%0d", seq.bl.name(), seq.ca5, seq.col, seq.col[3]), UVM_LOW)
		end

		else begin
			`uvm_error("SEQ_READ", "Address queue is empty")
		end
		

	endtask


endclass




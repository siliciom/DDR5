class ddr5_wr_bl16_otf_bl32_1600_seq extends uvm_sequence #(ddr5_seq_item);
	
	`uvm_object_utils(ddr5_wr_bl16_otf_bl32_1600_seq)

	ddr5_seq_item seq;
	ddr5_seq_item dummy_seq;


	rand bit [`BG_WIDTH-1:0]  target_bg;
  	rand bit [`BA_WIDTH-1:0]  target_ba;
  	rand bit [`ROW_WIDTH-1:0] target_row;
  	rand bit [`COL_WIDTH-1:0] target_col;
 
  	bit [`COL_WIDTH-1:0] col_addr[$];
  	bit [`COL_WIDTH-1:0] pop_addr;

	function new(string name = "ddr5_wr_bl16_otf_bl32_1600_seq");
		super.new(name);
	endfunction

	task body();
		
		seq=ddr5_seq_item::type_id::create("seq");
		`uvm_info("SEQ", "GENERATING TRANSACTION", UVM_LOW)

		// 1. MRW - Configure BL32 OTF
		start_item(seq);
		if(!seq.randomize() with {cmd == MRW; bl == BL32_OTF; rl == RL22; wr_preamble == WR_PRE_2TCK; wr_postamble == WR_PSTBLE_1_5TCK;})
			`uvm_error("SEQ_MRW", "MRW RANDOMIZATION FAILED")
		finish_item(seq);

		`uvm_info("SEQ_MRW", $sformatf("MRW -> BL=%s RL=%s WR_PRE=%s WR_POST=%s", seq.bl.name(), seq.rl.name(), seq.wr_preamble.name(), seq.wr_postamble.name()), UVM_LOW)

//randomization
    if (!this.randomize() with {target_col[2:0] ==  3'b000;})
      `uvm_error("SEQ_RAND", "Address randomization failed")

      
    `uvm_info("SEQ_RAND", $sformatf(" BL32 RANDOM_ADDR -> BG=%0d BA=%0d ROW=%0d TARGET_COL=%0d", target_bg, target_ba, target_row, target_col), UVM_LOW)

    		// 2. ACTIVATE 
		start_item(seq);

		if(!seq.randomize() with {cmd == ACTIVATE; bg == target_bg; ba == target_ba; row == target_row;})
			`uvm_error("SEQ_ACTIVATE", "ACTIVATE RANDOMIZATION FAILED")
		finish_item(seq);

		`uvm_info("SEQ_ACTIVATE",$sformatf("ACTIVATE BG %0d BA %0d ROW %0d", seq.bg, seq.ba, seq.row),UVM_LOW)

		// 3. WRITE - BL32 OTF
		
		start_item(seq);

		if(!seq.randomize() with {cmd == WRITE; bl == BL32_OTF; bg == target_bg; ba == target_ba; col[9:0] == target_col[9:0]; ca5 == 1'b1; col[10] == 1'b1;
		
		foreach(dq_burst[i])
			if(i > 0)
				dq_burst[i] != dq_burst[i-1];
			})

			`uvm_error("SEQ_WRITE", "BL32 WRITE RANDOMIZATION FAILED")

		seq.bl32_second_write = 1'b0;
		
	
		finish_item(seq);

		col_addr.push_back(seq.col);

		`uvm_info("SEQ_WRITE", $sformatf("BL32 OTF WRITE  BG %0d BA %0d ROW %0d COL %0d CA5 %0d COL[10] %0d DUMMY %0d", target_bg, target_ba, target_row, target_col, seq.ca5, seq.col[10], seq.bl32_second_write), UVM_LOW)

		// 3. DUMMY WRITE - BL32 OTF
		
		dummy_seq = ddr5_seq_item::type_id::create("dummy_seq");

		if (seq.ca5 == 1'b0) begin
		
		start_item(dummy_seq);

		if(!dummy_seq.randomize() with {cmd == WRITE; bl == BL32_OTF; bg == target_bg; ba == target_ba; col[9:0] == target_col[9:0]; ca5 == 1'b0; col[10] == 1'b1;
		
		foreach(dq_burst[i])
			if(i > 0)
				dq_burst[i] != dq_burst[i-1];

		})
			`uvm_error("SEQ_DUMMY WRITE", "BL32 DUMMY WRITE RANDOMIZATION FAILED")

		dummy_seq.bl32_second_write = 1'b1;
		

	//	col_addr.push_back(seq.col);

		finish_item(dummy_seq);

		`uvm_info("SEQ_DUMMY WRITE", $sformatf("BL32  DUMMY WRITE  BG %0d BA %0d ROW %0d COL %0d CA5 %0d COL[10] %0d DUMMY %0d", dummy_seq.bg, dummy_seq.ba, target_row, dummy_seq.col, dummy_seq.ca5, dummy_seq.col[10], dummy_seq.bl32_second_write), UVM_LOW)
		
		end

		// 4. READ - BL32 OTF
		if(col_addr.size() > 0) begin

		start_item(seq);

		pop_addr = col_addr.pop_front();

		if(!seq.randomize() with {cmd == READ; bl == BL32_OTF; bg == target_bg; ba == target_ba; col[9:0] == pop_addr[9:0]; ca5 == 1'b1; col[10] == 1'b0; })
			`uvm_error("SEQ_READ", "BL32 OTF READ RANDOMIZATION FAILED")
		finish_item(seq);

		`uvm_info("SEQ_READ", $sformatf("BL32 OTF READ BG %0d BA %0d COL %0d BL %0s RL %s", seq.bg, seq.ba, seq.col, seq.bl.name(), seq.rl.name()), UVM_LOW)
		end

		else begin
			`uvm_error("SEQ_READ", "Address queue is empty")
		end

		// 4. DUMMY READ - BL32 OTF
		if(seq.ca5 == 1'b0) begin

		start_item(dummy_seq);

	//	pop_addr = col_addr.pop_front();

		if(!dummy_seq.randomize() with {cmd == READ; bl == BL32_OTF; bg == target_bg; ba == target_ba; col[9:0] == pop_addr[9:0]; ca5 == 1'b0; col[10] == 1'b1; })
			`uvm_error("DUMMY_SEQ_READ", "BL32 OTF DUMMY READ RANDOMIZATION FAILED")
		finish_item(dummy_seq);

		`uvm_info("DUMMY_SEQ_READ", $sformatf("BL32 OTF DUMMY READ BG %0d BA %0d COL %0d BL %0s RL %s", dummy_seq.bg, dummy_seq.ba, dummy_seq.col, dummy_seq.bl.name(), dummy_seq.rl.name()), UVM_LOW)
		end

	
	endtask


endclass





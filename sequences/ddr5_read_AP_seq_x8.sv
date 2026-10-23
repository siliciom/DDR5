class ddr5_read_AP_seq_x8 extends uvm_sequence #(ddr5_seq_item);
 
	`uvm_object_utils(ddr5_read_AP_seq_x8)
 
	ddr5_seq_item seq;
 
	function new(string name = "ddr5_read_AP_seq_x8");

		super.new(name);

	endfunction
 
	task body();
 
		seq = ddr5_seq_item::type_id::create("seq");

		`uvm_info("READ_AP SEQ","Generating the Read_AP seq",UVM_LOW);
 
		//configure Mode Register

		start_item(seq);

		if(!seq.randomize with {cmd == MRW;bl == BL16; rl == RL22; wr_preamble == WR_PRE_3TCK; wr_postamble == WR_PSTBLE_1_5TCK;})

			`uvm_error("SEQ MRW","Failed to configure the Mode Register");

        finish_item(seq);
 
		`uvm_info("SEQ MRW",$sformatf("MRW : bl = %0d, rl = %0d",seq.bl,seq.rl),UVM_LOW);
 
        //Activate

        start_item(seq);

        if(!seq.randomize with {cmd == ACTIVATE; bg == 5; ba == 2; row == 10;})

            `uvm_error("SEQ ACT","Failed to activate the bank");

        finish_item(seq);
 
        `uvm_info("SEQ ACT",$sformatf("ACT: bg = %0d, ba = %0d, row = %0d",seq.bg,seq.ba, seq.row),UVM_LOW);
 
        //Normal Write

        start_item(seq);

        if(!seq.randomize with {cmd == WRITE; bg == 5; ba == 2; col == 8;ap_n == 1'b1;

        foreach(dm_burst[i])

            dm_burst[i] == 1;})

            `uvm_error("SEQ WRITE","Failed to Write");

        finish_item(seq);
 
        `uvm_info("SEQ WRITE",$sformatf("WRITE : bg = %0d, ba = %0d, col = %0d",seq.bg,seq.ba, seq.col),UVM_LOW);
 
 
        //Read_AP

       start_item(seq);

        if(!seq.randomize with {cmd == READ_AP; bg == 5; ba == 2; col == 8;ap_n == 1'b0;})

            `uvm_error("SEQ READ_AP","Failed to read in bank");

        finish_item(seq);
 
        `uvm_info("SEQ READ_AP",$sformatf("READ_AP : bg = %0d, ba = %0d, col = %0d",seq.bg, seq.ba, seq.col),UVM_LOW);
 
    endtask
 
endclass : ddr5_read_AP_seq_x8
 
 
 
 
 

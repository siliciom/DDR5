class ddr5_write_AP_seq_x8 extends uvm_sequence #(ddr5_seq_item);
 
    `uvm_object_utils(ddr5_write_AP_seq_x8)
 
    ddr5_seq_item seq;
 
    function new(string name = "ddr5_write_AP_seq_x8");

        super.new(name);

    endfunction
 
    task body();
 
        seq = ddr5_seq_item::type_id::create("seq");

        `uvm_info("seq","Generating transaction",UVM_LOW);
 
        start_item(seq);

        if(!seq.randomize with { cmd == MRW; bl == BL16; rl == RL22; wr_preamble == WR_PRE_3TCK; wr_postamble ==WR_PSTBLE_1_5TCK;})

            `uvm_error("seq_MRW","Randomization failed");

        finish_item(seq);
 
        `uvm_info("seq_MRW",$sformatf("MRW_SEQ bl= %0d RL = %0d",seq.bl,seq.rl),UVM_LOW);
 
 
        //Activate

        start_item(seq);

        if(!seq.randomize with {cmd == ACTIVATE; bg == 2; ba == 3; row == 50;})

            `uvm_error("Seq Activate","Rnadomization failed");

        finish_item(seq);
 
        `uvm_info("seq_Activate",$sformatf("Seq_ACT : bg=%0d, ba = %0d, row = %0d",seq.bg, seq.ba, seq.row),UVM_LOW);
 
        //Write with Auto precharge 

        start_item(seq);

        if(!seq.randomize with {cmd == WRITE_AP;bl == BL16; bg == 2; ba == 3; col == 16;ap_n == 1'b0;
 
		foreach(dm_burst[i])

		dm_burst[i] == 1'b1;
 
	

	})

            `uvm_error("seq Write","Randomization failed");

        finish_item(seq);
 
       `uvm_info("SEQ_WRITE",

    $sformatf("seq_Write: bg=%0d, ba=%0d, bl=%0d, col=%0d, wr_pre=%0d, wr_post=%0d",

              seq.bg, seq.ba, seq.bl, seq.col,

              seq.wr_preamble, seq.wr_postamble),

    UVM_LOW);
 
    //Another write

   /*  start_item(seq);

        if(!seq.randomize with {cmd == WRITE_AP;bl == BL16; bg == 2; ba == 3; col == 16;})

            `uvm_error("seq Write","Randomization failed");

        finish_item(seq);
 
       `uvm_info("SEQ_WRITE",

    $sformatf("seq_Write: bg=%0d, ba=%0d, bl=%0d, col=%0d, wr_pre=%0d, wr_post=%0d",

              seq.bg, seq.ba, seq.bl, seq.col,

              seq.wr_preamble, seq.wr_postamble),

    UVM_LOW);  

*/
 
/*

        //Activate

        start_item(seq);

        if(!seq.randomize with {cmd == ACTIVATE; bg == 2; ba == 3; row == 50;})

            `uvm_error("Seq_Activate","Randomization Failed");

        finish_item(seq);
 
        `uvm_info("Seq_Activate",$sformatf("seq_Activate : bg = %0d, ba = %0d, row = %0d",seq.bg,seq.ba,seq.row),UVM_LOW);
 
*/

        //READ

  /*     start_item(seq);

        if(!seq.randomize with {cmd == READ_AP; bl == BL16; bg == 2; ba == 3; col == 16;})

            `uvm_error("seq_Read","Randommization failed");

        finish_item(seq);
 
        `uvm_info("Seq_Read",$sformatf("seq_Read  bg = %0d, ba = %0d, bl = %0d, col = %0d",seq.bg,seq.ba,seq.bl,seq.col),UVM_LOW); */

 
    endtask
 
endclass : ddr5_write_AP_seq_x8
 
 
    
 
 
 

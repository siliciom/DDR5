class ddr5_write_DM_seq_x16 extends uvm_sequence #(ddr5_seq_item);
 
    `uvm_object_utils(ddr5_write_DM_seq_x16)
 
    ddr5_seq_item seq;
 
    function new(string name = "ddr5_write_DM_seq_x16");

        super.new(name);

    endfunction
 
 
task body();
 
       

        seq = ddr5_seq_item::type_id::create("seq");
 
        `uvm_info("SEQ",

                  "Generating the WRITE_x16_DM Transaction",

                  UVM_LOW);
 
 
          // CONFIGURE MRW
 
        start_item(seq);
 
        if(!seq.randomize with {

            cmd == MRW;

            bl == BL16;

            rl == RL22;
 
            dm_cfg == DM_ENABLE;
 
            wr_preamble == WR_PRE_3TCK;

            wr_postamble == WR_PSTBLE_1_5TCK;

        })

            `uvm_error("SEQ_MRW",

                       "Failed to configure MRW");
 
        finish_item(seq);
 
        `uvm_info("DM_MRW",

            $sformatf("DM ENABLED : dm_cfg=%0d bl=%0d rl=%0d",

                      seq.dm_cfg,

                      seq.bl,

                      seq.rl),

            UVM_LOW);
 
 
        //====================================================

        // ACTIVATE

        //====================================================
 
        start_item(seq);
 
        if(!seq.randomize with {

            cmd == ACTIVATE;

            bg  == 3;

            ba  == 1;

            row == 10;

        })

            `uvm_error("SEQ_ACTIVATE",

                       "Failed to Activate the bank");
 
        finish_item(seq);
 
        `uvm_info("DM_ACT",

            $sformatf("ACTIVATE : bg=%0d ba=%0d row=%0d",

                      seq.bg,

                      seq.ba,

                      seq.row),

            UVM_LOW);
 
 
        //====================================================

        // WRITE

        //====================================================
 
        start_item(seq);
 
       if(!seq.randomize with {
 
    cmd == WRITE;

    bl  == BL16;
 
    bg  == 3;

    ba  == 1;

    col == 15;

    ap_n == 1'b1;
 
    foreach(dml_burst[i])

    dml_burst[i] == ((i % 2) == 0);
 
    foreach(dmu_burst[i])

    dmu_burst[i] == ((i % 2) == 1);

})

    `uvm_error("SEQ_WRITE",

               "Failed to Write");
 
finish_item(seq);

        `uvm_info("DM_WRITE",

            $sformatf("WRITE : bg=%0d ba=%0d bl=%0d col=%0d",

                      seq.bg,

                      seq.ba,

                      seq.bl,

                      seq.col),

            UVM_LOW);
 
 
        //====================================================

        // READ

        //====================================================
 
    /*    start_item(seq);
 
        if(!seq.randomize with {
 
            cmd == READ;

            bl  == BL16;
 
            bg  == 3;

            ba  == 1;

            col == 15;

	    ap_n == 1'b1;
 
        })

            `uvm_error("DM_READ",

                       "READ randomization failed");
 
        finish_item(seq);
 
        `uvm_info("DM_READ",

            $sformatf("READ : bg=%0d ba=%0d col=%0d",

                      seq.bg,

                      seq.ba,

                      seq.col),

            UVM_LOW); */
 
    endtask
 
endclass : ddr5_write_DM_seq_x16
 
 
 
 

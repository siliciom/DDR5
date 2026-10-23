class ddr5_write_DM_seq_x8 extends uvm_sequence #(ddr5_seq_item);
 
    `uvm_object_utils(ddr5_write_DM_seq_x8)
 
    ddr5_seq_item seq;
 
    function new(string name = "ddr5_write_DM_seq_x8");

        super.new(name);

    endfunction

  rand bit [`BG_WIDTH-1:0]  target_bg;
 
  rand bit [`BA_WIDTH-1:0]  target_ba;
 
  rand bit [`ROW_WIDTH-1:0] target_row;
 
  rand bit [`COL_WIDTH-1:0] target_col;

  bit [`COL_WIDTH-1:0] col_addr[$];
 
  bit [`COL_WIDTH-1:0] pop_addr;
 
task body();
 
      

        seq = ddr5_seq_item::type_id::create("seq");
 
        `uvm_info("SEQ",

                  "Generating the WRITE_DM Transaction",

                  UVM_LOW);
 
 
        //====================================================

        // CONFIGURE MRW

        //====================================================
 
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

            bg  == target_bg;

            ba  == target_ba;

            row == target_row;

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
 
    cmd == WRITE_AP;

    bl  == BL16;
 
    bg  == target_bg;

    ba  == target_ba;

    col == target_col;

    ap_n == 1'b0;
 
    foreach(dm_burst[i])

        dm_burst[i] == ((i % 2) == 0);
 
})

    `uvm_error("SEQ_WRITE", "Failed to Write");
 
	       col_addr.push_back(seq.col);
 
finish_item(seq);

        `uvm_info("DM_WRITE", $sformatf("WRITE : bg=%0d ba=%0d bl=%0d col=%0d", seq.bg, seq.ba, seq.bl, seq.col),UVM_LOW);
 
       //Read
 
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
 
endclass : ddr5_write_DM_seq_x8
 
 

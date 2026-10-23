class ddr5_write_DM_test_x8 extends ddr5_test;
 
    `uvm_component_utils(ddr5_write_DM_test_x8)
 
   

    ddr5_write_DM_seq_x8 seq;

    function new(string name = "ddr5_write_DM_test_x8",uvm_component parent = null);

        super.new(name,parent);

    endfunction
 
   

    task run_phase(uvm_phase phase);
 
        seq = ddr5_write_DM_seq_x8::type_id::create("seq");
 
        phase.raise_objection(this);
 
        seq.start(envh.agt.seqh);
 
        #60000;
 
        phase.drop_objection(this);
 
    endtask
 
endclass : ddr5_write_DM_test_x8
 
 
 

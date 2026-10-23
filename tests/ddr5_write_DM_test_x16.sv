class ddr5_write_DM_test_x16 extends ddr5_test;
 
    `uvm_component_utils(ddr5_write_DM_test_x16)
 
     ddr5_write_DM_seq_x16 seq;

    function new(string name = "ddr5_write_DM_test_x16",uvm_component parent = null);

        super.new(name,parent);

    endfunction

 
    task run_phase(uvm_phase phase);
 
        phase.raise_objection(this);

	seq = ddr5_write_DM_seq_x16::type_id::create("seq");

        seq.start(envh.agt.seqh);
 
        #60000;
 
        phase.drop_objection(this);
 
    endtask
 
endclass : ddr5_write_DM_test_x16
 
 
 
 

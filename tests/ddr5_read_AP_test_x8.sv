class ddr5_read_AP_test_x8 extends ddr5_test;
 
    `uvm_component_utils(ddr5_read_AP_test_x8)
 
   

    ddr5_read_AP_seq_x8 seq;

 
    function new(string name = "ddr5_read_AP_test_x8",uvm_component parent = null);

        super.new(name,parent);

    endfunction

 
    task run_phase(uvm_phase phase);
 
        phase.raise_objection(this);
 
         seq = ddr5_read_AP_seq_x8::type_id::create("seq");
 
        seq.start(envh.agt.seqh);
 
        #60000;
 
        phase.drop_objection(this);
 
    endtask
 
 
endclass : ddr5_read_AP_test_x8
 
 
        

 

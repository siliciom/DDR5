class ddr5_wr_rd_test_x8 extends ddr5_test;
 
    `uvm_component_utils(ddr5_wr_rd_test_x8)
 
   

    ddr5_wr_rd_seq_x8 seq;

    function new(string name = "ddr5_wr_rd_test_x8",uvm_component parent = null);

        super.new(name,parent);

    endfunction
 
    
 
    task run_phase(uvm_phase phase);
 
        phase.raise_objection(this);
 
         seq = ddr5_wr_rd_seq_x8::type_id::create("seq");
 
        seq.start(envh.agt.seqh);
 
        #60000;
 
        phase.drop_objection(this);
 
    endtask
 
 
endclass : ddr5_wr_rd_test_x8
 
 
        
 
 
 

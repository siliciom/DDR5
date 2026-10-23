class ddr5_wr_rd_test_x4 extends ddr5_test;
 
  `uvm_component_utils(ddr5_wr_rd_test_x4)

 
  ddr5_wr_rd_seq_x4 seq;


  function new(string name ="ddr5_wr_rd_test_x4",uvm_component parent);

    super.new(name,parent);

  endfunction

 


     task run_phase (uvm_phase phase);

    phase.raise_objection(this);


       seq=ddr5_wr_rd_seq_x4::type_id::create("seq");
 


       seq.start(envh.agt.seqh);

       #50000;

       phase.drop_objection(this);

  endtask

endclass
 
 
 

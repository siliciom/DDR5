class ddr5_wr_rd_test_x16 extends ddr5_test;
 
  `uvm_component_utils(ddr5_wr_rd_test_x16)

 
  ddr5_wr_rd_seq_x16 seqh;


  function new(string name ="ddr5_wr_rd_test_x16",uvm_component parent);

    super.new(name,parent);

  endfunction

 


     task run_phase (uvm_phase phase);

    phase.raise_objection(this);


       seqh=ddr5_wr_rd_seq_x16::type_id::create("seqh");
 


       seqh.start(envh.agt.seqh);

       #50000;

       phase.drop_objection(this);

  endtask

endclass
 
 

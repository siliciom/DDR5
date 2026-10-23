class ddr5_tFAW_bank_1600_test extends ddr5_test;
 
  `uvm_component_utils(ddr5_tFAW_bank_1600_test)
 
    ddr5_tFAW_bank_1600_seq seqh;
 
   //   constructor

  function new(string name ="ddr5_tFAW_bank_1600_test",uvm_component parent);

    super.new(name,parent);

  endfunction

//   run phase

     task run_phase (uvm_phase phase);

    phase.raise_objection(this);

//        create sequence

       seqh=ddr5_tFAW_bank_1600_seq::type_id::create("seqh");

//        start sequence on sequencer

       seqh.start(envh.agt.seqh);

       #90000;

       phase.drop_objection(this);

  endtask

endclass

 

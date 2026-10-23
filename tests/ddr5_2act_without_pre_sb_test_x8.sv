class ddr5_2act_without_pre_sb_test_x8 extends uvm_test;
  `uvm_component_utils(ddr5_2act_without_pre_sb_test_x8)

  ddr5_env envh;
ddr5_2act_without_pre_sb_seq_x8 seqh;
virtual ddr5_interface vif;
  //   constructor
  function new(string name ="ddr5_2act_without_pre_sb_test_x8",uvm_component parent);
    super.new(name,parent);
  endfunction
//   build phase
  function void build_phase(uvm_phase phase);
	  uvm_factory factory = uvm_factory :: get();
    super.build_phase(phase);
    // Get interface from top TB
    if(!uvm_config_db #(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif))
      `uvm_fatal("TEST", "Did not get vif")
 
    // Set interface for all components (driver + monitor)
      uvm_config_db #(virtual ddr5_interface)::set(this, "*", "ddr5_interface", vif);
 
    
// Create environment
    envh = ddr5_env::type_id::create("envh",this);
    factory.print();
endfunction
 
//   stsrt of simulation
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
 
//   run phase
     task run_phase (uvm_phase phase);
    phase.raise_objection(this);
//        create sequence
seqh = ddr5_2act_without_pre_sb_seq_x8::type_id::create("seqh"); 
//        start sequence on sequencer
       seqh.start(envh.agt.seqh);
       #1000000;
       phase.drop_objection(this);
  endtask
endclass

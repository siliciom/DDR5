class ddr5_env extends uvm_env;
  `uvm_component_utils(ddr5_env)
  
  ddr5_agent agt;
  ddr5_scoreboard scrb;
  
  function new (string name = "ddr5_env", uvm_component parent);
    super.new(name,parent);
  endfunction 
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  
    agt = ddr5_agent::type_id::create("agt",this);
  
    scrb = ddr5_scoreboard::type_id::create("scrb",this);
  
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.monh.ddr5_ap.connect(scrb.sb_port);
  endfunction
  
endclass
 


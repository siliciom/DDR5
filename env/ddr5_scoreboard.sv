class ddr5_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ddr5_scoreboard)
//   analysis port
  uvm_analysis_imp #(ddr5_seq_item ,ddr5_scoreboard) sb_port;
  
//   constructor
  function new (string name = "ddr5_scoreboard", uvm_component parent);
    super.new(name,parent);
    sb_port = new("sb_port",this);
  endfunction
//   Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  
  function void write(ddr5_seq_item seq);
    `uvm_info("scb","scoreboard capturing data",UVM_LOW)
  //  seq.print();
    

  endfunction


endclass

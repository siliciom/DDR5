class ddr5_agent extends uvm_agent;
  `uvm_component_utils(ddr5_agent)
  
  ddr5_driver drvh;
  ddr5_sequencer seqh;
  ddr5_monitor monh;
  
  function new (string name = "ddr5_agent", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
   
    super.build_phase(phase);
    monh   = ddr5_monitor::type_id::create("monh",this);
    drvh   = ddr5_driver::type_id::create("drvh",this);
    seqh = ddr5_sequencer::type_id::create("seqh",this);
 
  endfunction
  
 function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
   drvh.seq_item_port.connect(seqh.seq_item_export);
     
  endfunction
  
endclass

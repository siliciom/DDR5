class ddr5_sequencer extends uvm_sequencer #(ddr5_seq_item);
  
  `uvm_component_utils(ddr5_sequencer)
  
  function new(string name ="ddr5_sequencer",uvm_component parent=null);
    super.new(name,parent);
  endfunction
endclass

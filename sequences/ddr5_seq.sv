class ddr5_seq extends uvm_sequence #(ddr5_seq_item);
  
  `uvm_object_utils(ddr5_seq)
   ddr5_seq_item seq;
  
  function new(string name ="ddr5_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(1)
      begin
        
        seq = ddr5_seq_item::type_id::create("seq");
        `uvm_info("SEQ", "Generating transaction", UVM_LOW)
        
        start_item(seq);
        assert(seq.randomize());
        finish_item(seq);
        
      end
  endtask
endclass

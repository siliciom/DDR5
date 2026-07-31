class ddr5_driver extends uvm_driver #(ddr5_seq_item);
  `uvm_component_utils(ddr5_driver)
  
  virtual ddr5_interface vif;
  
//   constructor
  function new(string name = "ddr5_driver",uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
//   build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
//     get interface
    if(!uvm_config_db #(virtual ddr5_interface)::get(this,"","ddr5_interface",vif))begin
      `uvm_fatal("DRV","NO INTERFACE")
    end
      endfunction
      
//       run phase uvm
      task run_phase(uvm_phase phase);
      ddr5_seq_item seq;
    super.run_phase(phase);
    
    forever
      begin
        seq_item_port.get_next_item(seq);
        send_to_dut(seq);
        seq_item_port.item_done();
      end
    endtask
    
  task send_to_dut(ddr5_seq_item seq);
    @(posedge vif.ck_t);
      
      `uvm_info("DRVH","driving the data",UVM_LOW)
    //  seq.print();
//        vif.ba   <= seq.ba;
//        vif.addr <= seq.addr;
//        vif.dq_o <= seq.dq_o;
//        vif.dq_i <= seq.dq_i;
    endtask
    endclass
       

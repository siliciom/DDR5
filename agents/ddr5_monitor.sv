class ddr5_monitor extends uvm_monitor;
  `uvm_component_utils(ddr5_monitor)
  
  virtual ddr5_interface vif;
  uvm_analysis_port#(ddr5_seq_item) ddr5_ap;

  
//   constructor
  function new(string name = "ddr5_monitor",uvm_component parent = null); 
    super.new(name,parent);
    ddr5_ap = new("ddr5_ap",this);
  endfunction
  
//   build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  
//   get interface 
  if(!uvm_config_db#(virtual ddr5_interface)::get(this,"","ddr5_interface",vif))
    `uvm_fatal("MON","NO INTERFACE")
    endfunction
    
//     runphase
    task run_phase(uvm_phase phase);
   forever
     begin
       
       data();
       
     end
  endtask
  
  task data();
    ddr5_seq_item seq;
    @(posedge vif.ck_t);
    seq = ddr5_seq_item::type_id::create("seq");
     

    `uvm_info("MONH","monitor captureing the data",UVM_LOW)
            //  seq.print();
              ddr5_ap.write(seq);
  endtask
endclass
    

class ddr5_wr_bl16_otf_bc8_1600_test extends uvm_test;

  `uvm_component_utils(ddr5_wr_bl16_otf_bc8_1600_test)

  ddr5_env envi;

  ddr5_wr_bl16_otf_bc8_1600_seq seqi;

  virtual ddr5_interface vif;

  // Contructor
    function new(string name = "ddr5_wr_bl16_otf_bc8_1600_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

  // Build Phase
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      // Get interface from top TB
      if(!uvm_config_db #(virtual ddr5_interface)::get(this, " ", "ddr5_interface", vif)) begin
           `uvm_fatal("TEST", "did not get vif")
      end

      // Set interface for all components (driver + monitor)
        uvm_config_db #(virtual ddr5_interface)::set(this, "*", "ddr5_interface", vif);
      
      envi = ddr5_env::type_id::create("envi", this);

    endfunction

    // Run Phase
      task run_phase(uvm_phase phase);
        phase.raise_objection(this);
          // create sequence
            seqi = ddr5_wr_bl16_otf_bc8_1600_seq::type_id::create("seqi");
            seqi.start(envi.agt.seqh);
            #90000;
        phase.drop_objection(this);
      endtask

endclass
       

  






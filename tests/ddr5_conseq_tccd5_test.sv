class ddr5_conseq_tccd5_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_conseq_tccd5_test)

  function new(string name = "ddr5_conseq_tccd5_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 13);
    super.build_phase(phase);
  endfunction

endclass


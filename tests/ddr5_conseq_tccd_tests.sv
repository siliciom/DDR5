// tCCD_S + 1 = 9 CK
class ddr5_tccd_plus1_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_tccd_plus1_test)

  function new(string name = "ddr5_tccd_plus1_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 9);
    super.build_phase(phase);
  endfunction

endclass


// tCCD_S + 2 = 10 CK
class ddr5_tccd_plus2_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_tccd_plus2_test)

  function new(string name = "ddr5_tccd_plus2_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 10);
    super.build_phase(phase);
  endfunction

endclass


// tCCD_S + 3 = 11 CK
class ddr5_tccd_plus3_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_tccd_plus3_test)

  function new(string name = "ddr5_tccd_plus3_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 11);
    super.build_phase(phase);
  endfunction

endclass


// tCCD_S + 4 = 12 CK
class ddr5_tccd_plus4_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_tccd_plus4_test)

  function new(string name = "ddr5_tccd_plus4_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 12);
    super.build_phase(phase);
  endfunction

endclass


// tCCD_S + 5 = 13 CK
class ddr5_tccd_plus5_test extends ddr5_mul_conseq_wr_rd_db_x8_test;

  `uvm_component_utils(ddr5_tccd_plus5_test)

  function new(string name = "ddr5_tccd_plus5_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    uvm_config_db#(int)::set(
      this, "envh.agt.drvh", "tccd_s_cfg", 13);
    super.build_phase(phase);
  endfunction

endclass

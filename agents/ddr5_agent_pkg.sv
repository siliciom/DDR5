package ddr5_agent_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"

   import ddr5_seq_pkg::*;

   `include "ddr5_sequencer.sv"
   `include "ddr5_driver.sv"
   `include "ddr5_monitor.sv"
   `include "ddr5_agent.sv"

endpackage

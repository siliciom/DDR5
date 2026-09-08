package ddr5_env_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"
  
  `include "../config/ddr5_defines.sv" 
   import ddr5_seq_pkg::*;
   import ddr5_agent_pkg::*;

   `include "ddr5_scoreboard.sv"
   `include "ddr5_env.sv"

endpackage

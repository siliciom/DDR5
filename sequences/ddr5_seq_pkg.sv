 package ddr5_seq_pkg;
 
   import uvm_pkg::*;
   `include "uvm_macros.svh"
   `include "../config/ddr5_defines.sv"
   `include "ddr5_seq_item.sv"
   `include "ddr5_seq.sv"
   `include "ddr5_seq_x8.sv"
 
  `include "ddr5_mul_conseq_wr_rd_db_x8_seq.sv"
  `include  "ddr5_mul_nonconseq_wr_rd_db_seq.sv"
  `include  "ddr5_mul_nonconseq_wr_rd_sb_x8_seq.sv"
  `include  "ddr5_mul_con_noncon_wr_rd_x8_seq.sv"
  `include  "ddr5_2act_without_pre_sb_seq_x8.sv"
  `include  "ddr5_wr_rd_without_act_seq_x8.sv"
     // jyotis
  `include  "ddr5_tFAW_4bank_1600_seq.sv"
  `include  "ddr5_tFAW_bank_1600_seq.sv"
  //bhaskar
 
  `include "ddr5_wr_rd_seq_x16.sv"
   `include "ddr5_wr_rd_seq_x8.sv"
   `include "ddr5_wr_rd_seq_x4.sv"
   `include "ddr5_write_AP_seq_x8.sv"
   `include "ddr5_write_DM_seq_x8.sv"
   `include "ddr5_write_DM_seq_x16.sv"
   `include "ddr5_read_AP_seq_x8.sv"

 
endpackage

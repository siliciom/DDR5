package ddr5_test_pkg;
 
   import uvm_pkg::*;
   `include "uvm_macros.svh"
   import ddr5_seq_pkg::*;
   import ddr5_env_pkg::*;

 
   `include "ddr5_test.sv"
   `include "ddr5_test_x8.sv"
   `include "ddr5_mul_nonconseq_wr_rd_db_test.sv"
   `include "ddr5_mul_conseq_wr_rd_db_x8_test.sv"
   `include "ddr5_conseq_tccd_tests.sv"
   `include "ddr5_mul_nonconseq_wr_rd_sb_x8_test.sv"
   `include "ddr5_mul_con_noncon_wr_rd_x8_test.sv"
   `include "ddr5_2act_without_pre_sb_test_x8.sv"
   `include  "ddr5_wr_rd_without_act_test_x8.sv"
    `include  "ddr5_conseq_tccd1_test.sv"
    `include  "ddr5_conseq_tccd2_test.sv"
    `include  "ddr5_conseq_tccd3_test.sv"
    `include  "ddr5_conseq_tccd4_test.sv"
    `include  "ddr5_conseq_tccd5_test.sv"




   //jyothi
   `include  "ddr5_tFAW_4bank_1600_test.sv"
   `include  "ddr5_tFAW_bank_1600_test.sv"
   //bhaskar
    `include "ddr5_wr_rd_test_x16.sv"
   `include "ddr5_wr_rd_test_x8.sv"
   `include "ddr5_wr_rd_test_x4.sv"
   `include "ddr5_write_AP_test_x8.sv"
   `include "ddr5_write_DM_test_x8.sv"
   `include "ddr5_write_DM_test_x16.sv"
   `include "ddr5_read_AP_test_x8.sv"

endpackage

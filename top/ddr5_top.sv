`timescale 1ns/1ps

`include "ddr5_interface.sv"

module ddr5_top;

  import uvm_pkg::*;
  import ddr5_pkg::*;

  localparam realtime tCK = (1000.0 / `CK_FREQ_MHZ) * 1ns;
  
  bit ck_t;
  bit ck_c=1;
  always #(tCK/2.0) ck_t = ~ck_t;
  always #(tCK/2.0) ck_c = ~ck_c;
  
  ddr5_interface vif(ck_t,ck_c);
  
  //Need to instiate the DUT

  initial begin
   
    uvm_config_db #(virtual ddr5_interface)::set(null,"*","ddr5_interface",vif);

    //     Start UVM_test
    run_test("ddr5_test");
  end
  
endmodule

`include "../config/ddr5_timingpar.sv"
`include "../config/ddr5_defines.sv"

interface ddr5_interface (
    input bit ck_t,
    input bit ck_c
);

  // Reset
  logic reset_n;

  // Command/Address
  logic        cs_n;
  logic [13:0] ca;
  logic [3:0] cmd;//
  // Data
  logic [`DATA_WIDTH-1:0] dq;

  // dqS
  logic dqs_t;
  logic dqs_c;

  // Data Mask
  logic dm_n;

  // Driver Clocking Block : True Clock

  clocking ddr5_drv_cb_t @(posedge ck_t);
    default input #1step output #1step;

    output reset_n;
    output cs_n;
    output ca;
    output dq;
    output dqs_t;
    output dqs_c;
    output dm_n;
    output cmd;
  endclocking

  // Driver Clocking Block : Complement Clock
  clocking ddr5_drv_cb_c @(posedge ck_c);
    default input #1step output #1step;

    output reset_n;
    output cs_n;
    output ca;
    output dq;
    output dqs_t;
    output dqs_c;
    output dm_n;
  endclocking

localparam realtime TCK     = 0.625;
localparam realtime TCK_QTR = TCK / 4;   // = 0.15625ns

clocking ddr5_wr_drv_cb_t @(posedge ck_t);
  output #1step          dq;
  output #(TCK_QTR)  dqs_t;
  output #(TCK_QTR)  dqs_c;
endclocking

clocking ddr5_wr_drv_cb_c @(posedge ck_c);
  output #1step        dq;
  output #(TCK_QTR)  dqs_t;
  output #(TCK_QTR)  dqs_c;
endclocking


  // Monitor Clocking Block : True Clock
  clocking ddr5_mon_cb_t @(negedge ck_t);
    default input #1step; 

    input reset_n;
    input cs_n;
    input ca;
    input dq;
    input dm_n;
    //output cmd;
    input dqs_t;
    input dqs_c;
  endclocking
 
// Monitor Clocking Block : Complement Clock
  clocking ddr5_mon_cb_c @(negedge ck_c);
    default input #1step;

    input reset_n;
    input cs_n;
    input ca;
    input dq;
    input dm_n;
    input dqs_t;
    input dqs_c;
  endclocking

  clocking ddr5_mon_pre_t_cb @(negedge ck_t);
  default input #1step;
  input dqs_t, dqs_c;
 endclocking

clocking ddr5_mon_pre_c_cb @(negedge ck_c);
  default input #1step;
  input dqs_t, dqs_c;
endclocking 
 
// Monitor Clocking Block : DQS True
clocking ddr5_mon_dqs_t_cb @(posedge dqs_t);
  default input #0;
 
  input dq;
  input dqs_t;
  input dqs_c;
 
endclocking
 
 
// Monitor Clocking Block : DQS Complement
clocking ddr5_mon_dqs_c_cb @(posedge dqs_c);
  default input #0;
 
  input dq;
  input dqs_t;
  input dqs_c;
 
endclocking


//==========================================================
    // 1. TINIT1
    // RESET_n must remain LOW for TINIT1 clock cycles
    //==========================================================

    property p_tinit1;
        @(posedge ck_t)
        $fell(reset_n) |-> !reset_n[*`TINIT1];
    endproperty

    a_tinit1: assert property(p_tinit1)
    else
        $error("TINIT1 VIOLATION: RESET_n was not LOW for TINIT1");


    // 2. TINIT3
    // After RESET_n goes HIGH, CS_n must remain LOW for TINIT3

    property p_tinit3;
        @(posedge ck_t)
        $rose(reset_n) |-> !cs_n[*`TINIT3];
    endproperty

    a_tinit3: assert property(p_tinit3)
    else
        $error("TINIT3 VIOLATION");


    // 3. TINIT4
    // After CS_n goes HIGH, it must remain HIGH for TINIT4

    property p_tinit4;
        @(posedge ck_t)
        $rose(cs_n) |-> cs_n[*`TINIT4];
    endproperty

    a_tinit4: assert property(p_tinit4)
    else
        $error("TINIT4 VIOLATION");


  
    // 5. TINIT5
    // After NOP command, CS_n must remain LOW for TINIT5

  property p_tinit5;
    @(posedge ck_t)
    $fell(cs_n) && (ca[4:0] == 5'b11111)
    |-> !cs_n[*`TINIT5];
endproperty

a_tinit5: assert property(p_tinit5)
else
    $error("TINIT5 VIOLATION");

    // 6. MRW CA1 -> CA2 CHECK

    property p_mrw_two_cycle;
        @(posedge ck_t)
        (!cs_n && ca[4:0] == 5'b00101)
        |=> cs_n;
    endproperty

    a_mrw_two_cycle: assert property(p_mrw_two_cycle)
    else
        $error("MRW TWO-CYCLE COMMAND VIOLATION");


    // 7. TMRD
   
    property p_tmrd;
        @(posedge ck_t) disable iff (!reset_n)

        (!cs_n && ca[4:0] == 5'b00101)
        |=> !( !cs_n && ca[4:0] == 5'b00101 )[*`TMRD];
    endproperty

    a_tmrd: assert property(p_tmrd)
    else
        $error("TMRD VIOLATION: MRW issued before TMRD completed");

//====================================================
// MRW: CA1 -> CA2
//====================================================
property p_mrw_ca1_ca2;
  @(posedge vif.ck_t)
    (vif.cs_n == 1'b0 &&
     vif.ca[4:0] == 5'b00101)
    |=>
    (vif.cs_n == 1'b1 &&
     vif.ca[13:8] == 6'b000000);
endproperty

a_mrw_ca1_ca2: assert property(p_mrw_ca1_ca2)
else
  $error("MRW FAILED: CA1 NOT FOLLOWED BY CORRECT CA2");

/*
//====================================================
// MRW: CA2 -> RELEASE CA
//====================================================
property p_mrw_ca2_release;
  @(posedge vif.ck_t)
    (vif.cs_n == 1'b1 &&
     vif.ca[13:8] == 6'b000000)
    |=>
    (vif.cs_n == 1'b1 &&
     vif.ca === 14'bz);
endproperty

a_mrw_ca2_release: assert property(p_mrw_ca2_release)
else
  $error("MRW FAILED: CA NOT RELEASED AFTER CA2");


//====================================================
// COMPLETE MRW SEQUENCE
//====================================================
property p_complete_mrw;
  @(posedge vif.ck_t)

    (vif.cs_n == 1'b0 &&
     vif.ca[4:0] == 5'b00101)

    ##1

    (vif.cs_n == 1'b1 &&
     vif.ca[13:8] == 6'b000000)

    ##1

    (vif.cs_n == 1'b1 &&
     vif.ca === 14'bz);
endproperty

a_complete_mrw: assert property(p_complete_mrw)
else
  $error("COMPLETE MRW SEQUENCE FAILED");

*/


endinterface

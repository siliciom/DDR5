interface ddr5_interface(
  input bit ck_t,
  input bit ck_c
);
//  reset signal
  logic RESET_n;
//  command and ADDRESS SIGNALS
  logic CS_n;
  logic[13:0] CA;
  // logic bg;
  // logic ba;
  // logic row;
  // logic clmn;
  
//   DATA SIGNALS
  logic DQ;
//DATA STROBES
  logic dqs_t;
  logic dqs_c;
// Data Mask  
  logic dm_n;
//control
  // ALERT_n;
  // CA_ODT;  
  
endinterface

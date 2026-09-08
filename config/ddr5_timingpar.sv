`timescale 1ns/1ps
   // INITILIZATION TIMINGS 
`define TINIT1 320 //Minimum RESET_n LOW time after completion of voltage 
`define  TINIT3 7 //Minimum CS_n LOW time after RESET_n HIGH
`define  TINIT4 4 //Minimum time for DRAM to register EXIT on CS_n
`define  TINIT5 5 //Minimum cycles required after CS_n HIGH
`define  TXPR 5 //Minimum time from exit reset to 1st valid configuration command
`define  TMRR 23  // Mode Register Read command period
`define  TMRR_P 8 // Mode Register Read Pattern to Mode Register Read Pattern cmd spacing
`define  TMRW 8 // Mode Register Write command period
`define  TMRD 23 //Mode Register Set command delay

  // NORMAL OPERATION TIMINGS  
`define TRAS 52 //ACTIVEto precharge command
`define TRCD 22  //Activate to READ or WRITE command
`define TRC  74    //ACTIVE to ACTIVE/AutoRefresh commandperiod
`define TRRD_S 8    //ACTIVE bankA to ACTIVE bankB command(Diff BG)
`define TRRD_L 8   //ACTIVE bankA to ACTIVE bankB command (same BG)

`define TWTR_S 4  //Internal Write to Read Command Delay
`define TWTRA TWR-TRTP //36 NEED TO SEE  //Internal Write to Read Command Delay
`define TWR 48 //Write recovery time
`define TRP 22 //PRECHARGE command period
`define TCL 22  //read cas latency 
`define TCWL 20 // Write  cas Latency
`define TAA  22 //internal read cmd to first data
`define TCCD_L 8 // CAS_n to CAS_n Delay (Same BG)
`define TCCD_L_WR 32 //WRITE CAS_n to WRITE CAS_n (Same BG)
`define TCCD_S 8    // CAS_n to CAS_n Delay (Diff BG)

`define TFAW 32 //Four Activate Window 
`define TRTP 12 //Internal READ to PRECHARGE Delay
`define TPPD 2 // PRECHARGE to PRECHARGE Delay
 


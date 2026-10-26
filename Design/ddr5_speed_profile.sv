`timescale 1ps/1ps

package ddr5_speed_profile;

  localparam int unsigned SPEED_GRADE_MT = 4800;
  localparam int unsigned CK_MHZ         = 2400;
  localparam int unsigned TCK_PS         = 416;

  localparam int unsigned CL       = 40;
  localparam int unsigned CWL      = 38;

  localparam int unsigned T_RCD    = 39;
  localparam int unsigned T_RP     = 39;
  localparam int unsigned T_RAS    = 77;
  localparam int unsigned T_RC     = 117;

  localparam int unsigned T_RRD_S  = 8;
  localparam int unsigned T_RRD_L  = 13;

  localparam int unsigned T_FAW    = 32;

  localparam int unsigned T_CCD_S  = 8;
  localparam int unsigned T_CCD_L  = 13;

  localparam int unsigned T_CCD_L_WR  = 49;
  localparam int unsigned T_CCD_L_WR2 = 25;
  localparam int unsigned T_CCD_S_WR  = 8;

  localparam int unsigned T_RTP    = 19;

  localparam int unsigned T_WR     = 72;

  localparam int unsigned T_WTR_S  = 52;

  localparam int unsigned T_WTR_L  = 70;

  localparam int unsigned T_RFC1   = 710;
  localparam int unsigned T_RFC2   = 385;
  localparam int unsigned T_RFCSB  = 313;

  localparam int unsigned T_REFI1  = 9375;
  localparam int unsigned T_REFI2  = 4688;

  localparam int unsigned T_MRD    = 16;
  localparam int unsigned T_MRW    = 8;
endpackage

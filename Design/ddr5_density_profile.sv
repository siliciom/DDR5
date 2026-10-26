`timescale 1ps/1ps

package ddr5_density_profile;

  localparam int unsigned DATA_WIDTH   = 8;
  localparam int unsigned NUM_BG       = 8;
  localparam int unsigned BA_PER_BG    = 4;
  localparam int unsigned NUM_BANKS    = 32;
  localparam int unsigned ROW_BITS     = 16;
  localparam int unsigned COL_BITS     = 10;
  localparam int unsigned PAGE_BYTES   = 1024;
  localparam bit C10_VALID = 1'b0;
endpackage

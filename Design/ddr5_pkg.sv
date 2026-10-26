`timescale 1ps/1ps

package ddr5_pkg;

  typedef enum logic [5:0] {
    CMD_DES=6'd0,
    CMD_NOP=6'd1,
    CMD_ACT=6'd2,
    CMD_WRP=6'd3,
    CMD_WRPA=6'd4,
    CMD_MRW=6'd5,
    CMD_MRR=6'd6,
    CMD_WR=6'd7,
    CMD_WRA=6'd8,
    CMD_RD=6'd9,
    CMD_RDA=6'd10,
    CMD_VREFCA=6'd11,
    CMD_VREFCS=6'd12,
    CMD_REFAB=6'd13,
    CMD_RFMAB=6'd14,
    CMD_REFSB=6'd15,
    CMD_RFMSB=6'd16,
    CMD_PREAB=6'd17,
    CMD_PRESB=6'd18,
    CMD_PREPB=6'd19,
    CMD_SRE=6'd20,
    CMD_SREF=6'd21,
    CMD_PDE=6'd22,
    CMD_MPC=6'd23,
    CMD_PDX=6'd24,
    CMD_RSVD25=6'd25,
    CMD_RSVD26=6'd26,
    CMD_SRX=6'd27,
    CMD_UNKNOWN=6'd63
  } ddr5_cmd_e;

  typedef enum logic [1:0] {
    BURST_BL16=2'b00,
    BURST_BC8=2'b01,
    BURST_BL32=2'b10,
    BURST_RSVD=2'b11
  } burst_mode_e;

  localparam int unsigned DATA_WIDTH     = 8;
  localparam int unsigned CA_WIDTH       = 14;
  localparam int unsigned BG_WIDTH       = 3;
  localparam int unsigned BA_WIDTH       = 2;
  localparam int unsigned BANK_WIDTH     = 5;
  localparam int unsigned NUM_BG         = 8;
  localparam int unsigned BANKS_PER_BG   = 4;
  localparam int unsigned NUM_BANKS      = 32;
  localparam int unsigned ROW_WIDTH      = 16;
  localparam int unsigned COL_WIDTH      = 10;
  localparam int unsigned MR_WIDTH       = 8;
  localparam int unsigned MR_COUNT       = 256;
  localparam int unsigned BL16_BEATS     = 16;
  localparam int unsigned BL16_DATA_WIDTH= 128;

  function automatic logic [BANK_WIDTH-1:0] bank_index(
    input logic [BG_WIDTH-1:0] bg,
    input logic [BA_WIDTH-1:0] ba
  );
    bank_index = {bg, ba};
  endfunction
endpackage

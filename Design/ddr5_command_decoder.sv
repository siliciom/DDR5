`timescale 1ps/1ps

module ddr5_command_decoder (
  input  logic [13:0] ca1,
  input  logic [13:0] ca2,
  input  logic        cs1,
  input  logic        cs2,
  input  logic        power_down_state,
  input  logic        self_refresh_state,
  output ddr5_pkg::ddr5_cmd_e cmd,
  output logic        valid,
  output logic [2:0]  bg,
  output logic [1:0]  ba,
  output logic [15:0] row,
  output logic [9:0]  col,
  output logic [7:0]  mr_addr,
  output logic [7:0]  mr_data,
  output logic        auto_precharge,
  output logic        partial_write,
  output logic [7:0]  mpc_op,
  output logic [6:0]  vref_op,
  output logic [1:0]  pre_mode
);
  import ddr5_pkg::*;
  logic [4:0] class_code;

  always_comb begin
    class_code = ca1[4:0];

    case ({ca1[13:12], ca2[13:12]})
      4'b0000, 4'b0001, 4'b0010, 4'b0011,
      4'b0100, 4'b0101, 4'b0110, 4'b0111,
      4'b1000, 4'b1001, 4'b1010, 4'b1011,
      4'b1100, 4'b1101, 4'b1110, 4'b1111: begin end
    endcase

    cmd = CMD_UNKNOWN;
    valid = 1'b0;
    bg = '0;
    ba = '0;
    row = '0;
    col = '0;
    mr_addr = '0;
    mr_data = '0;
    auto_precharge = 1'b0;
    partial_write = 1'b0;
    mpc_op = '0;
    vref_op = '0;
    pre_mode = '0;

    if (cs1) begin

      cmd = CMD_DES;
      valid = 1'b1;
    end else if (!ca1[1]) begin

      case (class_code)
        5'b00000: begin

          cmd = CMD_ACT;
          valid = !cs2;
          row[3:0]  = ca1[5:2];
          row[15:4] = ca2[11:0];
          ba        = ca1[7:6];
          bg        = ca1[10:8];
        end
        5'b01001: begin

          ba  = ca1[7:6];
          bg  = ca1[10:8];
          col[9:3] = ca2[7:1];
          auto_precharge = !ca2[10];
          cmd = auto_precharge ? CMD_WRPA : CMD_WRP;
          valid = !cs2;
        end
        5'b00101: begin

          cmd = CMD_MRW;
          valid   = !cs2;
          mr_addr = ca1[12:5];
          mr_data = ca2[7:0];
        end
        5'b10101: begin

          cmd = CMD_MRR;
          valid   = !cs2;
          mr_addr = ca1[12:5];
        end
        5'b01101: begin

          ba  = ca1[7:6];
          bg  = ca1[10:8];
          col[9:3]       = ca2[7:1];
          auto_precharge = !ca2[10];
          partial_write  = !ca2[11];
          cmd = auto_precharge ? CMD_WRA : CMD_WR;
          valid = !cs2;
        end
        5'b11101: begin

          ba  = ca1[7:6];
          bg  = ca1[10:8];
          col[2]         = ca2[0];
          col[9:3]       = ca2[7:1];
          auto_precharge = !ca2[10];
          cmd = auto_precharge ? CMD_RDA : CMD_RD;
          valid = !cs2;
        end
        default: begin end
      endcase
    end else begin

      case (class_code)
        5'b00011: begin

          cmd     = !ca1[11] ? CMD_VREFCA : CMD_VREFCS;
          valid   = 1'b1;
          vref_op = ca1[10:4];
        end
        5'b10011: begin

          if (!ca1[11]) begin
            cmd = ca1[10] ? CMD_REFAB : CMD_RFMAB;
          end else begin
            cmd = ca1[10] ? CMD_REFSB : CMD_RFMSB;
            ba  = ca1[7:6];
          end
          valid = 1'b1;
        end
        5'b01011: begin

          if (!ca1[11]) begin
            cmd      = CMD_PREAB;
            pre_mode = 2'd0;
          end else begin
            cmd      = CMD_PRESB;
            pre_mode = 2'd1;
            ba       = ca1[7:6];
          end
          valid = 1'b1;
        end
        5'b11011: begin

          cmd      = CMD_PREPB;
          pre_mode = 2'd2;
          bg       = ca1[10:8];
          ba       = ca1[7:6];
          valid    = 1'b1;
        end
        5'b10111: begin

          if      (ca1[10]) cmd = CMD_PDE;
          else if (ca1[9])  cmd = CMD_SRE;
          else              cmd = CMD_SREF;
          valid = 1'b1;
        end
        5'b01111: begin

          cmd    = CMD_MPC;
          valid  = 1'b1;
          mpc_op = ca1[12:5];
        end
        5'b11111: begin

          if      (self_refresh_state) cmd = CMD_SRX;
          else if (power_down_state)   cmd = CMD_PDX;
          else                         cmd = CMD_NOP;
          valid = 1'b1;
        end
        default: begin end
      endcase
    end
  end
endmodule

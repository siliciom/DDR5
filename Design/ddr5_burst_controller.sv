`timescale 1ps/1ps

module ddr5_burst_controller (
  input  logic [9:0] start_col,
  input  logic [1:0] burst_mode,
  input  logic       read_mode,
  input  logic       enable_bl32,
  input  logic [5:0] beat,
  output logic [9:0] burst_col,
  output logic       burst_done
);
  logic [4:0] burst_index;

  function automatic logic [3:0] read_bl16_map(
    input logic [1:0] c3_c2,
    input logic [3:0] b
  );
    begin
      case (c3_c2)
        2'b00: read_bl16_map = b;
        2'b01: begin
          case (b)
            4'd0: read_bl16_map=4'h4; 4'd1: read_bl16_map=4'h5;
            4'd2: read_bl16_map=4'h6; 4'd3: read_bl16_map=4'h7;
            4'd4: read_bl16_map=4'h0; 4'd5: read_bl16_map=4'h1;
            4'd6: read_bl16_map=4'h2; 4'd7: read_bl16_map=4'h3;
            4'd8: read_bl16_map=4'hC; 4'd9: read_bl16_map=4'hD;
            4'd10: read_bl16_map=4'hE; default: read_bl16_map=4'hF;
          endcase
        end
        2'b10: begin
          case (b)
            4'd0: read_bl16_map=4'h8; 4'd1: read_bl16_map=4'h9;
            4'd2: read_bl16_map=4'hA; 4'd3: read_bl16_map=4'hB;
            4'd4: read_bl16_map=4'hC; 4'd5: read_bl16_map=4'hD;
            4'd6: read_bl16_map=4'hE; 4'd7: read_bl16_map=4'hF;
            4'd8: read_bl16_map=4'h0; 4'd9: read_bl16_map=4'h1;
            4'd10: read_bl16_map=4'h2; default: read_bl16_map=4'h3;
          endcase
        end
        default: begin
          case (b)
            4'd0: read_bl16_map=4'hC; 4'd1: read_bl16_map=4'hD;
            4'd2: read_bl16_map=4'hE; 4'd3: read_bl16_map=4'hF;
            4'd4: read_bl16_map=4'h8; 4'd5: read_bl16_map=4'h9;
            4'd6: read_bl16_map=4'hA; 4'd7: read_bl16_map=4'hB;
            4'd8: read_bl16_map=4'h4; 4'd9: read_bl16_map=4'h5;
            4'd10: read_bl16_map=4'h6; default: read_bl16_map=4'h7;
          endcase
        end
      endcase
    end
  endfunction

  function automatic logic [3:0] read_bc8_map(
    input logic [1:0] c3_c2,
    input logic [2:0] b
  );
    begin
      case (c3_c2)
        2'b00: read_bc8_map = {1'b0,b};
        2'b01: read_bc8_map = (b < 3'd4) ? (4'h4 + b) : (b - 3'd4);
        2'b10: read_bc8_map = 4'h8 + b;
        default: read_bc8_map = (b < 3'd4) ? (4'hC + b) : (4'h8 + (b - 3'd4));
      endcase
    end
  endfunction

  always_comb begin

    case (start_col[1:0])
      2'b00, 2'b01, 2'b10, 2'b11: begin end
    endcase
    burst_index = '0;
    burst_done = 1'b0;
    case (burst_mode)
      2'b01: begin
        if (read_mode) burst_index = {1'b0, read_bc8_map(start_col[3:2], beat[2:0])};
        else burst_index = start_col[3] ? (5'd8 + {2'b00, beat[2:0]}) : {2'b00, beat[2:0]};
        burst_done = (beat == 6'd7);
      end
      2'b00: begin
        if (read_mode) burst_index = {1'b0, read_bl16_map(start_col[3:2], beat[3:0])};
        else burst_index = {1'b0, beat[3:0]};
        burst_done = (beat == 6'd15);
      end
      2'b10, 2'b11: begin
        if (enable_bl32) begin
          burst_index = beat[4:0];
          burst_done = (beat == 6'd31);
        end else begin

          burst_index = {1'b0, beat[3:0]};
          burst_done = (beat == 6'd15);
        end
      end
      default: begin end
    endcase

    if ((burst_mode == 2'b00) || (burst_mode == 2'b01) || !enable_bl32)
      burst_col = {start_col[9:4], burst_index[3:0]};
    else
      burst_col = {start_col[9:5], burst_index};
  end
endmodule

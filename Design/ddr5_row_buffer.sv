`timescale 1ps/1ps

module ddr5_row_buffer (
  input  logic        ck,
  input  logic        reset_n,
  input  logic        act_valid,
  input  logic [4:0]  act_bank,
  input  logic [15:0] act_row,
  input  logic        pre_pb,
  input  logic        pre_sb,
  input  logic        pre_ab,
  input  logic [4:0]  pre_bank,
  input  logic        auto_precharge_event,
  input  logic [4:0]  auto_precharge_bank,
  output logic [31:0] row_valid,
  output logic [15:0] open_row [0:31]
);
  integer i;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      row_valid <= '0;
      for (i = 0; i < 32; i = i + 1) begin
        open_row[i] <= '0;
      end
    end else begin
      if (act_valid) begin
        row_valid[act_bank] <= 1'b1;
        open_row[act_bank] <= act_row;
      end
      if (pre_ab) begin
        row_valid <= '0;
      end else if (pre_sb) begin
        for (i = 0; i < 8; i = i + 1) begin
          row_valid[{i[2:0], pre_bank[1:0]}] <= 1'b0;
        end
      end else if (pre_pb) begin
        row_valid[pre_bank] <= 1'b0;
      end
      if (auto_precharge_event) begin
        row_valid[auto_precharge_bank] <= 1'b0;
      end
    end
  end
endmodule

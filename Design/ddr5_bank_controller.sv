`timescale 1ps/1ps

module ddr5_bank_controller (
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
  output logic [31:0] active,
  output logic [15:0] open_row [0:31],
  output logic        act_legal,
  output logic        pre_legal
);
  integer i;

  always_comb begin
    act_legal = !active[act_bank];
    pre_legal = active[pre_bank];
  end

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      active <= '0;
      for (i = 0; i < 32; i = i + 1) begin
        open_row[i] <= '0;
      end
    end else begin

      if (act_valid && act_legal) begin
        active[act_bank] <= 1'b1;
        open_row[act_bank] <= act_row;
      end

      if (pre_ab) begin
        active <= '0;
      end else if (pre_sb) begin

        for (i = 0; i < 8; i = i + 1) begin
          active[{i[2:0], pre_bank[1:0]}] <= 1'b0;
        end
      end else if (pre_pb && pre_legal) begin
        active[pre_bank] <= 1'b0;
      end

      if (auto_precharge_event) begin
        active[auto_precharge_bank] <= 1'b0;
      end
    end
  end
endmodule

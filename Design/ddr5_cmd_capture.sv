`timescale 1ps/1ps

module ddr5_cmd_capture (
  input  logic        ck,
  input  logic        reset_n,
  input  logic        cs_n,
  input  logic [13:0] ca,
  input  logic        mode_2n,
  output logic        pair_valid,
  output logic [13:0] ca1,
  output logic [13:0] ca2,
  output logic        cs1,
  output logic        cs2
);
  logic pending_q;
  logic mode_2n_q;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      pending_q  <= 1'b0;
      mode_2n_q  <= 1'b0;
      pair_valid <= 1'b0;
      ca1        <= '0;
      ca2        <= '0;
      cs1        <= 1'b1;
      cs2        <= 1'b1;
    end else begin
      pair_valid <= 1'b0;
      mode_2n_q  <= mode_2n;

      if (!pending_q) begin

        if (!cs_n) begin
          ca1 <= ca;
          cs1 <= 1'b0;
          if (ca[1]) begin

            ca2        <= '0;
            cs2        <= 1'b1;
            pair_valid <= 1'b1;
          end else begin

            pending_q <= 1'b1;
          end
        end
      end else begin

        ca2        <= ca;
        cs2        <= cs_n;
        pending_q  <= 1'b0;
        pair_valid <= 1'b1;
      end
    end
  end
endmodule

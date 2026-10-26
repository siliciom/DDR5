`timescale 1ps/1ps

module ddr5_init_fsm (
  input  logic ck,
  input  logic reset_n,
  input  logic zq_present,
  input  logic zq_complete,
  input  logic training_done,
  output logic init_done,
  output logic issue_mrw,
  output logic issue_mpc,
  output logic issue_zq,
  output logic issue_training
);
  typedef enum logic [2:0] {S_RESET,S_WAIT,S_MRW,S_ZQ,S_TRAIN,S_READY} state_t;
  state_t state_q;

  localparam int unsigned TINIT3_CYCLES = 2048;
  logic [11:0] count_q;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      state_q <= S_RESET;
      count_q <= '0;
    end else begin
      case (state_q)
        S_RESET: begin
          state_q <= S_WAIT; count_q <= '0;
        end
        S_WAIT: begin
          if (count_q == TINIT3_CYCLES[11:0]) begin state_q <= S_MRW; count_q <= '0; end
          else count_q <= count_q + 1'b1;
        end
        S_MRW:   begin state_q <= S_ZQ;    count_q <= '0; end
        S_ZQ:    begin
          if (zq_present && zq_complete) begin state_q <= S_TRAIN; count_q <= '0; end
        end
        S_TRAIN: begin
          if (training_done) state_q <= S_READY;
        end
        S_READY: state_q <= S_READY;
        default: state_q <= S_RESET;
      endcase
    end
  end

  always_comb begin
    init_done      = (state_q == S_READY);
    issue_mrw      = (state_q == S_MRW);
    issue_mpc      = (state_q == S_TRAIN);
    issue_zq       = (state_q == S_ZQ);
    issue_training = (state_q == S_TRAIN);
  end
endmodule

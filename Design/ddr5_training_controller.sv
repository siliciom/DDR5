`timescale 1ps/1ps

module ddr5_training_controller (
  input  logic ck,
  input  logic reset_n,
  input  logic start,
  input  logic read_training_en,
  input  logic write_leveling_en,
  output logic ca_done,
  output logic cs_done,
  output logic wl_done,
  output logic rd_done,
  output logic vref_done,
  output logic done,
  output logic training_error
);
  typedef enum logic [2:0] {ST_IDLE,ST_CA,ST_CS,ST_WL,ST_RD,ST_VREF,ST_DONE} state_t;
  state_t state_q;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      state_q <= ST_IDLE;
    end else begin
      case (state_q)
        ST_IDLE: if (start) state_q <= ST_CA;
        ST_CA: state_q <= ST_CS;
        ST_CS: state_q <= write_leveling_en ? ST_WL : ST_RD;
        ST_WL: state_q <= read_training_en ? ST_RD : ST_VREF;
        ST_RD: state_q <= ST_VREF;
        ST_VREF: state_q <= ST_DONE;
        ST_DONE: state_q <= ST_DONE;
        default: state_q <= ST_IDLE;
      endcase
    end
  end

  always_comb begin
    ca_done = (state_q == ST_CS) || (state_q == ST_WL) || (state_q == ST_RD) || (state_q == ST_VREF) || (state_q == ST_DONE);
    cs_done = (state_q == ST_WL) || (state_q == ST_RD) || (state_q == ST_VREF) || (state_q == ST_DONE);
    wl_done = (state_q == ST_RD) || (state_q == ST_VREF) || (state_q == ST_DONE);
    rd_done = (state_q == ST_VREF) || (state_q == ST_DONE);
    vref_done = (state_q == ST_DONE);
    done = (state_q == ST_DONE);
    training_error = 1'b0;
  end
endmodule

`timescale 1ps/1ps

module ddr5_odt_vref_zq (
  input  logic       ck,
  input  logic       reset_n,
  input  logic [7:0] mr32,
  input  logic [7:0] mr33,
  input  logic [7:0] vrefca_code,
  input  logic [7:0] vrefcs_code,
  input  logic [7:0] vrefdq_code,
  input  logic       vrefca_in,
  input  logic       vrefdq_in,
  input  logic       zq_command,
  output logic       odt_active,
  output logic       zq_done,
  output logic [7:0] vrefca,
  output logic [7:0] vrefcs,
  output logic [7:0] vrefdq
);
  logic [7:0] zq_count;

  always_ff @(posedge ck or negedge reset_n) begin
    if (!reset_n) begin
      odt_active <= 1'b0;
      zq_done <= 1'b0;
      zq_count <= '0;
    end else begin
      odt_active <= (mr32 != 8'h00) || (mr33 != 8'h00);
      zq_done <= 1'b0;
      if (zq_command) begin
        zq_count <= 8'd1;
      end else if (zq_count != 0) begin
        if (zq_count >= 8'd100) begin zq_done <= 1'b1; zq_count <= '0; end
        else zq_count <= zq_count + 1'b1;
      end
    end
  end

  always_comb begin
    vrefca = vrefca_in ? vrefca_code : 8'h00;
    vrefcs = vrefca_in ? vrefcs_code : 8'h00;
    vrefdq = vrefdq_in ? vrefdq_code : 8'h00;
  end
endmodule

`timescale 1ps/1ps

module ddr5_memory_array #(
  parameter int unsigned MODEL_BANKS = 32,
  parameter int unsigned MODEL_ROWS  = 64,
  parameter int unsigned MODEL_COLS  = 64
) (
  input  logic        ck,
  input  logic        write_en,
  input  logic        read_en,
  input  logic [4:0]  bank,
  input  logic [15:0] row,
  input  logic [9:0]  col,
  input  logic [127:0] write_data,
  input  logic [15:0]  write_ecc,
  output logic [127:0] read_data,
  output logic [15:0]  read_ecc
);
  localparam int unsigned ROW_STRIDE  = MODEL_COLS;
  localparam int unsigned BANK_STRIDE = MODEL_ROWS * MODEL_COLS;
  localparam int unsigned ADDR_COUNT  = MODEL_BANKS * BANK_STRIDE;
  logic [127:0] mem [0:ADDR_COUNT-1];
  logic [15:0]  ecc_mem [0:ADDR_COUNT-1];

  localparam int unsigned INDEX_W = (ADDR_COUNT <= 1) ? 1 : $clog2(ADDR_COUNT);
  logic [INDEX_W-1:0] idx;
  logic [INDEX_W-1:0] bank_idx, row_idx, col_idx;

  always_comb begin
    bank_idx = bank % MODEL_BANKS;
    row_idx = row % MODEL_ROWS;
    col_idx = col % MODEL_COLS;

    idx = (bank_idx * INDEX_W'(BANK_STRIDE)) +
          (row_idx  * INDEX_W'(ROW_STRIDE)) + col_idx;
    if (read_en) begin
      read_data = mem[idx];
      read_ecc = ecc_mem[idx];
    end else begin
      read_data = '0;
      read_ecc = '0;
    end
  end

  always_ff @(posedge ck) begin
    if (write_en) begin
      mem[idx] <= write_data;
      ecc_mem[idx] <= write_ecc;
    end
  end
endmodule

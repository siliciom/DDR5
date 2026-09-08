class ddr5_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(ddr5_scoreboard)

  // Analysis Port
  uvm_analysis_imp #(ddr5_seq_item, ddr5_scoreboard) sb_port;

  bit [`DATA_WIDTH-1:0] mem [0:(1<<`BG_WIDTH)-1][0:(1<<`BA_WIDTH)-1][bit [`ROW_WIDTH-1:0]][bit [`COL_WIDTH-1:0]];
 
  bit bank_active[0:(1<<`BG_WIDTH)-1][0:(1<<`BA_WIDTH)-1];
 
  bit [`ROW_WIDTH-1:0] active_row[0:(1<<`BG_WIDTH)-1][0:(1<<`BA_WIDTH)-1];
 
  function new(string name = "ddr5_scoreboard",uvm_component parent = null);
    super.new(name,parent);
    sb_port = new("sb_port",this);
  endfunction
 
  function void compare(
    bit [`BG_WIDTH-1:0] bg,
    bit [`BA_WIDTH-1:0] ba,
    bit [`ROW_WIDTH-1:0] row,
    bit [`COL_WIDTH-1:0] col,
    int beat,
    bit [`DATA_WIDTH-1:0] actual,
    bit [`DATA_WIDTH-1:0] expected
  );
  
    if (actual === expected) begin
      `uvm_info("DDR5_SB_PASS", $sformatf("MATCH BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d EXP=%0h ACT=%0h", bg, ba, row, col, beat, expected, actual), UVM_LOW)
    end
    else begin
`uvm_error("DDR5_SB_FAIL", $sformatf("MISMATCH BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d EXP=%0h ACT=%0h", bg, ba, row, col, beat, expected, actual))
    end

  endfunction

    function automatic void get_wr_preamble_pattern(input bit [1:0] mode, output bit pattern[0:7], output int len);
    case (mode)
      WR_PRE_2TCK: begin len = 4; pattern[0:3] = '{0,0,1,0};         end
      WR_PRE_3TCK: begin len = 6; pattern[0:5] = '{0,0,0,0,1,0};     end
      WR_PRE_4TCK: begin len = 8; pattern[0:7] = '{0,0,0,0,1,0,1,0}; end
      default:     begin len = 0;                                   end
    endcase
  endfunction

   function automatic void get_rd_preamble_pattern(input bit [2:0] mode, output bit pattern[0:7], output int len);
    case (mode)
      3'b000: begin len = 2; pattern[0:1] = '{1,0};             end
      3'b001: begin len = 4; pattern[0:3] = '{0,0,1,0};         end
      3'b010: begin len = 4; pattern[0:3] = '{1,1,1,0};         end
      3'b011: begin len = 6; pattern[0:5] = '{0,0,0,0,1,0};     end
      3'b100: begin len = 8; pattern[0:7] = '{0,0,0,0,1,0,1,0}; end
      default: begin len = 0;                                  end
    endcase
  endfunction

  // Monitor -> Scoreboard
  function void write(ddr5_seq_item seq);

    bit [`ROW_WIDTH-1:0] row;
    bit [`COL_WIDTH-1:0] col_addr;
    bit [`DATA_WIDTH-1:0] expected;

    case (seq.cmd)

      // ACTIVATE
      ACTIVATE: begin
        active_row[seq.bg][seq.ba] = seq.row;
        bank_active[seq.bg][seq.ba] = 1'b1;

        `uvm_info("DDR5_SB", $sformatf("ACTIVATE BG=%0d BA=%0d ROW=%0d", seq.bg, seq.ba, seq.row), UVM_LOW)
      end

      // WRITE
      WRITE: begin

        bit wr_preamble_valid;
        bit wr_dqs_valid;
        bit expected_wr_pattern[0:7];
        int wr_preamble_len;

        if (!bank_active[seq.bg][seq.ba]) begin
          `uvm_error("DDR5_SB", $sformatf("WRITE ON CLOSED BANK BG=%0d BA=%0d", seq.bg, seq.ba))
          return;
        end

        row = active_row[seq.bg][seq.ba];

        `uvm_info("DDR5_SB", $sformatf("WRITE BG=%0d BA=%0d ROW=%0d COL=%0d", seq.bg, seq.ba, row, seq.col), UVM_LOW)
        get_wr_preamble_pattern(seq.wr_preamble, expected_wr_pattern, wr_preamble_len);

        wr_preamble_valid = (wr_preamble_len != 0);

        if (wr_preamble_len == 0) begin
          `uvm_error("DDR5_SB_WR_PREAMBLE",
            $sformatf("UNSUPPORTED/RESERVED WRITE PREAMBLE MODE=%0d", seq.wr_preamble))
        end

        for (int i = 0; i < wr_preamble_len; i++) begin

          // DQS_T must match the exact expected bit for this sample
          if (seq.dqs_t_preamble[i] !== expected_wr_pattern[i]) begin

            wr_preamble_valid = 0;

            `uvm_error("DDR5_SB_WR_PREAMBLE",$sformatf("WRITE PREAMBLE PATTERN MISMATCH AT SAMPLE=%0d EXPECTED DQS_T=%b GOT DQS_T=%b",i, expected_wr_pattern[i], seq.dqs_t_preamble[i]))

          end

          // DQS_C must be the complement of DQS_T at every sample
          if (seq.dqs_c_preamble[i] !== ~expected_wr_pattern[i]) begin

            wr_preamble_valid = 0;

          `uvm_error("DDR5_SB_WR_PREAMBLE",$sformatf("WRITE PREAMBLE DQS_C NOT COMPLEMENT AT SAMPLE=%0d EXPECTED DQS_C=%b GOT DQS_C=%b",i, ~expected_wr_pattern[i], seq.dqs_c_preamble[i]))

          end

        end

        wr_dqs_valid = 1;

        if (wr_preamble_valid) begin

          for (int i = 0; i < 16; i++) begin

            // a) First burst edge must rise out of the preamble hold
            if (i == 0 && (seq.dqs_t_burst[0] !== 1'b1 || seq.dqs_c_burst[0] !== 1'b0)) begin
              wr_dqs_valid = 0;
              `uvm_error("DDR5_SB_WR_DQS_START",
                $sformatf("WRITE DQS DID NOT RISE OUT OF PREAMBLE, DQS_T[0]=%b DQS_C[0]=%b", seq.dqs_t_burst[0], seq.dqs_c_burst[0]))
            end

            // b) DQS_T / DQS_C must be a legal differential pair
            if (seq.dqs_t_burst[i] !== ~seq.dqs_c_burst[i]) begin
              wr_dqs_valid = 0;
              `uvm_error("DDR5_SB_WR_DQS_DIFF", $sformatf("WRITE DQS NOT DIFFERENTIAL AT BEAT=%0d DQS_T=%b DQS_C=%b", i, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))
            end

            // c) DQS_T and DQS_C must both toggle every beat (nothing to compare at beat 0)
            if (i > 0 && seq.dqs_t_burst[i] === seq.dqs_t_burst[i-1]) begin
              wr_dqs_valid = 0;
              `uvm_error("DDR5_SB_WR_DQS_TOGGLE",$sformatf("WRITE DQS_T DID NOT TOGGLE AT BEAT=%0d DQS_T=%b", i, seq.dqs_t_burst[i]))
            end

            if (i > 0 && seq.dqs_c_burst[i] === seq.dqs_c_burst[i-1]) begin
              wr_dqs_valid = 0;
              `uvm_error("DDR5_SB_WR_DQS_TOGGLE", $sformatf("WRITE DQS_C DID NOT TOGGLE AT BEAT=%0d DQS_C=%b", i, seq.dqs_c_burst[i]))
            end

          end

        end
        else begin
          wr_dqs_valid = 0;
        end

     // preamble & DQS Valid 
        if (wr_preamble_valid && wr_dqs_valid) begin

          for (int i = 0; i < 16; i++) begin
            col_addr = seq.col + i;
            mem[seq.bg][seq.ba][row][col_addr] = seq.dq_burst[i];

            `uvm_info("DDR5_SB_WRITE", $sformatf("STORE BG=%0d BA=%0d ROW=%0d COL=%0d DATA=%0h", seq.bg, seq.ba, row, col_addr, seq.dq_burst[i]), UVM_LOW)
          end

        end
        else begin

          `uvm_error("DDR5_SB", $sformatf("WRITE DATA NOT STORED - INVALID PREAMBLE/DQS BG=%0d BA=%0d ROW=%0d COL=%0d", seq.bg, seq.ba, row, seq.col))

        end

      end

READ: begin

  bit rd_preamble_valid;
  bit rd_dqs_valid;
  bit expected_rd_pattern[0:7];
  int rd_preamble_len;

  if (!bank_active[seq.bg][seq.ba]) begin
    `uvm_error("DDR5_SB", $sformatf("READ ON CLOSED BANK BG=%0d BA=%0d", seq.bg, seq.ba))
    return;
  end

  row = active_row[seq.bg][seq.ba];

  `uvm_info("DDR5_SB", $sformatf("READ BG=%0d BA=%0d ROW=%0d COL=%0d", seq.bg, seq.ba, row, seq.col), UVM_LOW)

  // 1) READ PREAMBLE PATTERN CHECK
 
  get_rd_preamble_pattern(seq.rd_preamble, expected_rd_pattern, rd_preamble_len);

  rd_preamble_valid = (rd_preamble_len != 0);

  if (rd_preamble_len == 0) begin
    `uvm_error("DDR5_SB_RD_PREAMBLE",
      $sformatf("UNSUPPORTED/RESERVED READ PREAMBLE MODE=%0d", seq.rd_preamble))
  end

  for (int i = 0; i < rd_preamble_len; i++) begin

    // DQS_T must match the exact expected bit for this sample
    if (seq.dqs_t_preamble[i] !== expected_rd_pattern[i]) begin

      rd_preamble_valid = 0;

      `uvm_error("DDR5_SB_RD_PREAMBLE",
        $sformatf("READ PREAMBLE PATTERN MISMATCH AT SAMPLE=%0d EXPECTED DQS_T=%b GOT DQS_T=%b",
                   i, expected_rd_pattern[i], seq.dqs_t_preamble[i]))

    end

    // DQS_C must be the complement of DQS_T at every sample
    if (seq.dqs_c_preamble[i] !== ~expected_rd_pattern[i]) begin

      rd_preamble_valid = 0;

      `uvm_error("DDR5_SB_RD_PREAMBLE",
        $sformatf("READ PREAMBLE DQS_C NOT COMPLEMENT AT SAMPLE=%0d EXPECTED DQS_C=%b GOT DQS_C=%b",
                   i, ~expected_rd_pattern[i], seq.dqs_c_preamble[i]))

    end

  end

  // 2) READ DATA DQS CHECK
  
  rd_dqs_valid = 1;

  if (rd_preamble_valid) begin

    for (int i = 0; i < 16; i++) begin

      // a) First burst edge must rise out of the preamble hold
      if (i == 0 && (seq.dqs_t_burst[0] !== 1'b1 || seq.dqs_c_burst[0] !== 1'b0)) begin
        rd_dqs_valid = 0;
        `uvm_error("DDR5_SB_RD_DQS_START",
          $sformatf("READ DQS DID NOT RISE OUT OF PREAMBLE, DQS_T[0]=%b DQS_C[0]=%b", seq.dqs_t_burst[0], seq.dqs_c_burst[0]))
      end

      // b) DQS_T / DQS_C must be a legal differential pair
      if (seq.dqs_t_burst[i] !== ~seq.dqs_c_burst[i]) begin
        rd_dqs_valid = 0;
        `uvm_error("DDR5_SB_RD_DQS_DIFF",
          $sformatf("READ DQS NOT DIFFERENTIAL AT BEAT=%0d DQS_T=%b DQS_C=%b", i, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))
      end

      // c) DQS_T and DQS_C must both toggle every beat (nothing to compare at beat 0)
      if (i > 0 && seq.dqs_t_burst[i] === seq.dqs_t_burst[i-1]) begin
        rd_dqs_valid = 0;
        `uvm_error("DDR5_SB_RD_DQS_TOGGLE",
          $sformatf("READ DQS_T DID NOT TOGGLE AT BEAT=%0d DQS_T=%b", i, seq.dqs_t_burst[i]))
      end

      if (i > 0 && seq.dqs_c_burst[i] === seq.dqs_c_burst[i-1]) begin
        rd_dqs_valid = 0;
        `uvm_error("DDR5_SB_RD_DQS_TOGGLE",
          $sformatf("READ DQS_C DID NOT TOGGLE AT BEAT=%0d DQS_C=%b", i, seq.dqs_c_burst[i]))
      end

    end

  end
  else begin
    rd_dqs_valid = 0;
  end

  // COMPARE DATA ONLY IF PREAMBLE + DQS ARE BOTH VALID
  if (rd_preamble_valid && rd_dqs_valid) begin

    for (int i = 0; i < 16; i++) begin

      col_addr = seq.col + i;

      if (mem[seq.bg][seq.ba][row].exists(col_addr)) begin

        expected = mem[seq.bg][seq.ba][row][col_addr];

        compare(seq.bg, seq.ba, row, col_addr, i, seq.dq_burst[i], expected);

      end
      else begin

        `uvm_error("DDR5_SB", $sformatf("READ ADDRESS NEVER WRITTEN BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d", seq.bg, seq.ba, row, col_addr, i))

      end

    end

  end
  else begin

    `uvm_error("DDR5_SB", $sformatf("READ DATA NOT COMPARED - INVALID PREAMBLE/DQS BG=%0d BA=%0d ROW=%0d COL=%0d", seq.bg, seq.ba, row, seq.col))

  end

end

 
    endcase
 
  endfunction
endclass

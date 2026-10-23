`include "../config/ddr5_timingpar.sv"
 
class ddr5_scoreboard extends uvm_scoreboard;
 
    `uvm_component_utils(ddr5_scoreboard)
 
    uvm_analysis_imp #(ddr5_seq_item, ddr5_scoreboard) sb_port;
 
  

    bit [`DATA_WIDTH-1:0] mem

        [0:(1<<`BG_WIDTH)-1]

        [0:(1<<`BA_WIDTH)-1]

        [bit [`ROW_WIDTH-1:0]]

        [bit [`COL_WIDTH-1:0]];
 
    bit bank_active

        [0:(1<<`BG_WIDTH)-1]

        [0:(1<<`BA_WIDTH)-1];
 
    bit [`ROW_WIDTH-1:0] active_row

        [0:(1<<`BG_WIDTH)-1]

        [0:(1<<`BA_WIDTH)-1];
 
	// tFAW timing check

	realtime tCK;

	realtime current_time;

	realtime activate_time[$];
 
        function void build_phase(uvm_phase phase);

	 super.build_phase(phase);

	 if (!uvm_config_db#(realtime)::get(this, "", "tCK", tCK))

    `uvm_fatal("DDR5_SB", "tCK not configured")

  `uvm_info("DDR5_SB", $sformatf("tCK = %0.3f ns", tCK), UVM_LOW)

	endfunction

 
    function new(string name = "ddr5_scoreboard", uvm_component parent = null);

        super.new(name, parent);

        sb_port = new("sb_port", this);

    endfunction
 
 
    // Compare Expected vs Actual

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
 
 
    

    // WRITE PREAMBLE

    function automatic void get_wr_preamble_pattern(

        input bit [1:0] mode,

        output bit pattern[0:7],

        output int len

    );
 
        case (mode)
 
            WR_PRE_2TCK: begin

                len = 4;

                pattern[0:3] = '{0, 0, 1, 0};

            end
 
            WR_PRE_3TCK: begin

                len = 6;

                pattern[0:5] = '{0, 0, 0, 0, 1, 0};

            end
 
            WR_PRE_4TCK: begin

                len = 8;

                pattern[0:7] = '{0, 0, 0, 0, 1, 0, 1, 0};

            end
 
            default: begin

                len = 0;

            end
 
        endcase
 
    endfunction
 
 
        // READ PREAMBLE

        function automatic void get_rd_preamble_pattern(

        input bit [2:0] mode,

        output bit pattern[0:7],

        output int len

    );
 
        case (mode)
 
            3'b000: begin

                len = 2;

                pattern[0:1] = '{1, 0};

            end
 
            3'b001: begin

                len = 4;

                pattern[0:3] = '{0, 0, 1, 0};

            end
 
            3'b010: begin

                len = 4;

                pattern[0:3] = '{1, 1, 1, 0};

            end
 
            3'b011: begin

                len = 6;

                pattern[0:5] = '{0, 0, 0, 0, 1, 0};

            end
 
            3'b100: begin

                len = 8;

                pattern[0:7] = '{0, 0, 0, 0, 1, 0, 1, 0};

            end
 
            default: begin

                len = 0;

            end
 
        endcase
 
    endfunction
 
 
    // COMMON DATA MASK CHECK

    // Supports x4 / x8 / x16

       function automatic void dm_check(

        input ddr5_seq_item seq,

        input bit [`ROW_WIDTH-1:0] row,

        input bit [`COL_WIDTH-1:0] col_addr,

        input int beat

    );
 
        bit [`DATA_WIDTH-1:0] expected;
 
        if (`DATA_WIDTH == 16) begin
 
            case ({seq.dml_burst[beat], seq.dmu_burst[beat]})
 
                // DML=1, DMU=1

                // Store lower byte + upper byte
 
                2'b11: begin
 
                    mem[seq.bg][seq.ba][row][col_addr] = seq.dq_burst[beat];
 
                    `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DML_n=1 DMU_n=1 | LOWER + UPPER STORED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
                end
 
 
                // DML=1, DMU=0

                // Store lower byte

                // Mask upper byte
 
                2'b10: begin
 
                    if (mem[seq.bg][seq.ba][row].exists(col_addr))

                        expected = mem[seq.bg][seq.ba][row][col_addr];

                    else

                        expected = '0;
 
                    expected[7:0] = seq.dq_burst[beat][7:0];
 
                    mem[seq.bg][seq.ba][row][col_addr] = expected;
 
                    `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DML_n=1 DMU_n=0 | LOWER STORED | UPPER MASKED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
                end
 
 
                // DML=0, DMU=1

                // Mask lower byte

                // Store upper byte
 
                2'b01: begin
 
                    if (mem[seq.bg][seq.ba][row].exists(col_addr))

                        expected = mem[seq.bg][seq.ba][row][col_addr];

                    else

                        expected = '0;
 
                    expected[15:8] = seq.dq_burst[beat][15:8];
 
                    mem[seq.bg][seq.ba][row][col_addr] = expected;
 
                    `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DML_n=0 DMU_n=1 | LOWER MASKED | UPPER STORED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
                end
 
 
                // DML=0, DMU=0

                // Mask lower byte + upper byte
 
                2'b00: begin
 
                    if (!mem[seq.bg][seq.ba][row].exists(col_addr))

                        mem[seq.bg][seq.ba][row][col_addr] = '0;
 
                    `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DML_n=0 DMU_n=0 | LOWER + UPPER MASKED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
                end
 
 
                default: begin
 
                    `uvm_error("DM_RESULT", $sformatf("INVALID DML/DMU VALUE: DML=%b DMU=%b BEAT=%0d", seq.dml_burst[beat], seq.dmu_burst[beat], beat))
 
                end
 
            endcase
 
        end
 
 
               // x8

        else if (`DATA_WIDTH == 8) begin
 
            // DM_n = 1 -> Store data
 
            if (seq.dm_burst[beat]) begin
 
                mem[seq.bg][seq.ba][row][col_addr] = seq.dq_burst[beat];
 
                `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DM_n=1 | DATA STORED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
            end
 
 
            // DM_n = 0 -> Mask data
 
            else begin
 
                if (mem[seq.bg][seq.ba][row].exists(col_addr))

                    expected = mem[seq.bg][seq.ba][row][col_addr];

                else

                    expected = '0;
 
                mem[seq.bg][seq.ba][row][col_addr] = expected;
 
                `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | DM_n=0 | DATA MASKED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
            end
 
        end
 
 
                // x4 DM is not supported

               else begin
 
            mem[seq.bg][seq.ba][row][col_addr] = seq.dq_burst[beat];
 
            `uvm_info("DM_RESULT", $sformatf("BEAT[%0d] DQ=%0h | x4 | DATA STORED | MEM=%0h", beat, seq.dq_burst[beat], mem[seq.bg][seq.ba][row][col_addr]), UVM_LOW)
 
        end
 
    endfunction
 
 
    function void clear_after_reset();
 
    for (int bg = 0; bg < (1 << `BG_WIDTH); bg++) begin

        for (int ba = 0; ba < (1 << `BA_WIDTH); ba++) begin
 
            bank_active[bg][ba] = 1'b0;

            active_row[bg][ba]  = '0;
 
        //    mem[bg][ba].delete();
 
        end

    end
 
    activate_time.delete();

    `uvm_info("DDR5_SB","RESET RECEIVED - BANK STATE CLEARED", UVM_LOW)
 
endfunction
 
    function automatic bit write_common( input ddr5_seq_item seq,  input string cmd_name);
 
    bit [`ROW_WIDTH-1:0] row;

    bit [`COL_WIDTH-1:0] col_addr;

    bit wr_preamble_valid;

    bit wr_dqs_valid;

    bit expected_wr_pattern[0:7];

    int wr_preamble_len;
 
 
    if (!bank_active[seq.bg][seq.ba]) begin

        `uvm_error("DDR5_SB", $sformatf("%s ON CLOSED BANK BG=%0d BA=%0d", cmd_name, seq.bg, seq.ba))

        return 1'b0;

    end
 
 
    row = active_row[seq.bg][seq.ba];
 
    `uvm_info("SCOREBOARD", $sformatf("%s : BG=%0d BA=%0d ROW=%0d COL=%0d", cmd_name, seq.bg, seq.ba, row, seq.col), UVM_LOW)
 
 
    // Team-mate feature: consecutive writes may not have a separate

    // preamble to validate. Skip ONLY the preamble check for seamless writes

    // and interamble writes with observed TCCD from 9 through 13 CK.

    // DQS/DQSL/DQSU burst validation and data storage still run below.

    if (seq.seamless_write ||

        ((seq.observed_write_tccd >= 9) &&

         (seq.observed_write_tccd <= 13))) begin
 
        wr_preamble_valid = 1'b1;

        `uvm_info("DDR5_SB_WR_PREAMBLE",

            $sformatf("%s CONSECUTIVE WRITE: PREAMBLE CHECK SKIPPED TCCD=%0d SEAMLESS=%0b",

                      cmd_name, seq.observed_write_tccd, seq.seamless_write),

            UVM_LOW)

    end

    else begin

        get_wr_preamble_pattern(

            seq.wr_preamble,

            expected_wr_pattern,

            wr_preamble_len

        );
 
        wr_preamble_valid = (wr_preamble_len != 0);
 
        if (wr_preamble_len == 0) begin

            `uvm_error("DDR5_SB_WR_PREAMBLE",

                $sformatf("%s UNSUPPORTED/RESERVED WRITE PREAMBLE MODE=%0d",

                          cmd_name, seq.wr_preamble))

        end
 
        if (wr_preamble_valid) begin

            for (int i = 0; i < wr_preamble_len; i++) begin

                if (`DATA_WIDTH == 16) begin

                    if (seq.dqsl_t_preamble[i] !== expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQSL_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_wr_pattern[i], seq.dqsl_t_preamble[i]))

                    end
 
                    if (seq.dqsl_c_preamble[i] !== ~expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQSL_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_wr_pattern[i], seq.dqsl_c_preamble[i]))

                    end
 
                    if (seq.dqsu_t_preamble[i] !== expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQSU_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_wr_pattern[i], seq.dqsu_t_preamble[i]))

                    end
 
                    if (seq.dqsu_c_preamble[i] !== ~expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQSU_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_wr_pattern[i], seq.dqsu_c_preamble[i]))

                    end

                end

                else begin

                    if (seq.dqs_t_preamble[i] !== expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQS_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_wr_pattern[i], seq.dqs_t_preamble[i]))

                    end
 
                    if (seq.dqs_c_preamble[i] !== ~expected_wr_pattern[i]) begin

                        wr_preamble_valid = 1'b0;

                        `uvm_error("DDR5_SB_WR_PREAMBLE", $sformatf("%s PREAMBLE DQS_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_wr_pattern[i], seq.dqs_c_preamble[i]))

                    end

                end

            end

        end

    end

   // WRITE DATA STROBE CHECK

wr_dqs_valid = 1'b1;
 
if (wr_preamble_valid) begin

    for (int i = 0; i < 16; i++) begin

        if (`DATA_WIDTH == 16) begin

            // DQSL must remain differential

            if (seq.dqsl_t_burst[i] !== ~seq.dqsl_c_burst[i]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSL_DIFF", $sformatf("%s WRITE DQSL NOT DIFFERENTIAL BEAT=%0d DQSL_T=%b DQSL_C=%b", cmd_name, i, seq.dqsl_t_burst[i], seq.dqsl_c_burst[i]))

            end
 
            // DQSL_T must toggle

            if (i > 0 && seq.dqsl_t_burst[i] === seq.dqsl_t_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSL_TOGGLE", $sformatf("%s WRITE DQSL_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end
 
            // DQSL_C must toggle

            if (i > 0 && seq.dqsl_c_burst[i] === seq.dqsl_c_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSL_TOGGLE", $sformatf("%s WRITE DQSL_C DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end
 
            // DQSU must remain differential

            if (seq.dqsu_t_burst[i] !== ~seq.dqsu_c_burst[i]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSU_DIFF", $sformatf("%s WRITE DQSU NOT DIFFERENTIAL BEAT=%0d DQSU_T=%b DQSU_C=%b", cmd_name, i, seq.dqsu_t_burst[i], seq.dqsu_c_burst[i]))

            end
 
            // DQSU_T must toggle

            if (i > 0 && seq.dqsu_t_burst[i] === seq.dqsu_t_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSU_TOGGLE", $sformatf("%s WRITE DQSU_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end
 
            // DQSU_C must toggle

            if (i > 0 && seq.dqsu_c_burst[i] === seq.dqsu_c_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQSU_TOGGLE", $sformatf("%s WRITE DQSU_C DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end

        end

        else begin

            // DQS must remain differential

            if (seq.dqs_t_burst[i] !== ~seq.dqs_c_burst[i]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQS_DIFF", $sformatf("%s WRITE DQS NOT DIFFERENTIAL BEAT=%0d DQS_T=%b DQS_C=%b", cmd_name, i, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))

            end
 
            // DQS_T must toggle

            if (i > 0 && seq.dqs_t_burst[i] === seq.dqs_t_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQS_TOGGLE", $sformatf("%s WRITE DQS_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end
 
            // DQS_C must toggle

            if (i > 0 && seq.dqs_c_burst[i] === seq.dqs_c_burst[i-1]) begin

                wr_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_WR_DQS_TOGGLE", $sformatf("%s WRITE DQS_C DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end

        end

    end

end

else begin
 
    wr_dqs_valid = 1'b0;

end   

    if (wr_preamble_valid && wr_dqs_valid) begin
 
        for (int i = 0; i < 16; i++) begin
 
            col_addr = seq.col + i;
 
            dm_check(seq,row,col_addr,i);
 
        end
 
    end

    else begin
 
        `uvm_error("DDR5_SB", $sformatf("%s DATA NOT STORED - INVALID PREAMBLE BG=%0d BA=%0d ROW=%0d COL=%0d", cmd_name, seq.bg, seq.ba, row, seq.col))
 
        return 1'b0;
 
    end
 
 
    return 1'b1;
 
endfunction
 
function automatic bit check_read_command(

    input ddr5_seq_item seq,

    input string cmd_name

);

    if (!bank_active[seq.bg][seq.ba]) begin

        `uvm_error("DDR5_SB",

            $sformatf("%s ON CLOSED BANK BG=%0d BA=%0d",

                      cmd_name, seq.bg, seq.ba))

        return 1'b0;

    end
 
    `uvm_info("DDR5_SB",

        $sformatf("%s COMMAND CHECK PASSED BG=%0d BA=%0d ROW=%0d COL=%0d",

                  cmd_name, seq.bg, seq.ba, seq.row, seq.col),

        UVM_LOW)
 
    return 1'b1;

endfunction
 
//read common data

function automatic bit read_common(

    input ddr5_seq_item seq,

    input string cmd_name

);
 
    bit [`ROW_WIDTH-1:0] row;

    bit [`COL_WIDTH-1:0] col_addr;

    bit [`DATA_WIDTH-1:0] expected;
 
    bit rd_preamble_valid;

    bit rd_dqs_valid;
 
    bit expected_rd_pattern[0:7];

    int rd_preamble_len;
 
 
    if (!bank_active[seq.bg][seq.ba]) begin

        `uvm_error("DDR5_SB", $sformatf("%s ON CLOSED BANK BG=%0d BA=%0d", cmd_name, seq.bg, seq.ba))

        return 1'b0;

    end
 
 
    row = active_row[seq.bg][seq.ba];
 
    `uvm_info("SCOREBOARD", $sformatf("%s : BG=%0d BA=%0d ROW=%0d COL=%0d", cmd_name, seq.bg, seq.ba, row, seq.col), UVM_LOW)
 
 
    get_rd_preamble_pattern(

        seq.rd_preamble,

        expected_rd_pattern,

        rd_preamble_len

    );
 
 
    rd_preamble_valid = (rd_preamble_len != 0);
 
 
    if (rd_preamble_len == 0) begin
 
        `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s UNSUPPORTED/RESERVED READ PREAMBLE MODE=%0d", cmd_name, seq.rd_preamble))
 
    end


   // READ PREAMBLE CHECK

if (rd_preamble_valid) begin

    for (int i = 0; i < rd_preamble_len; i++) begin

        if (`DATA_WIDTH == 16) begin

            if (seq.dqsl_t_preamble[i] !== expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQSL_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_rd_pattern[i], seq.dqsl_t_preamble[i]))

            end
 
            if (seq.dqsl_c_preamble[i] !== ~expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQSL_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_rd_pattern[i], seq.dqsl_c_preamble[i]))

            end
 
            if (seq.dqsu_t_preamble[i] !== expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQSU_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_rd_pattern[i], seq.dqsu_t_preamble[i]))

            end
 
            if (seq.dqsu_c_preamble[i] !== ~expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQSU_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_rd_pattern[i], seq.dqsu_c_preamble[i]))

            end

        end

        else begin

            if (seq.dqs_t_preamble[i] !== expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQS_T MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, expected_rd_pattern[i], seq.dqs_t_preamble[i]))

            end
 
            if (seq.dqs_c_preamble[i] !== ~expected_rd_pattern[i]) begin

                rd_preamble_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_PREAMBLE", $sformatf("%s PREAMBLE DQS_C MISMATCH SAMPLE=%0d EXP=%b GOT=%b", cmd_name, i, ~expected_rd_pattern[i], seq.dqs_c_preamble[i]))

            end

        end

    end

end
 
 
   // READ DATA STROBE CHECK

rd_dqs_valid = 1'b1;
 
if (rd_preamble_valid) begin

    for (int i = 0; i < 16; i++) begin

        if (`DATA_WIDTH == 16) begin

            if (i == 0) begin

                if ((seq.dqsl_t_burst[i] !== 1'b1) ||

                    (seq.dqsl_c_burst[i] !== 1'b0) ||

                    (seq.dqsu_t_burst[i] !== 1'b1) ||

                    (seq.dqsu_c_burst[i] !== 1'b0)) begin

                    rd_dqs_valid = 1'b0;

                    `uvm_error("DDR5_SB_RD_DQS_START", $sformatf("%s x16 DQS DID NOT RISE OUT OF PREAMBLE BEAT=%0d DQSL=%b/%b DQSU=%b/%b", cmd_name, i, seq.dqsl_t_burst[i], seq.dqsl_c_burst[i], seq.dqsu_t_burst[i], seq.dqsu_c_burst[i]))

                end

            end
 
            if (seq.dqsl_t_burst[i] !== ~seq.dqsl_c_burst[i]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQSL_DIFF", $sformatf("%s DQSL NOT DIFFERENTIAL BEAT=%0d DQSL_T=%b DQSL_C=%b", cmd_name, i, seq.dqsl_t_burst[i], seq.dqsl_c_burst[i]))

            end
 
            if (i > 0 && seq.dqsl_t_burst[i] === seq.dqsl_t_burst[i-1]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQSL_TOGGLE", $sformatf("%s DQSL_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end
 
            if (seq.dqsu_t_burst[i] !== ~seq.dqsu_c_burst[i]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQSU_DIFF", $sformatf("%s DQSU NOT DIFFERENTIAL BEAT=%0d DQSU_T=%b DQSU_C=%b", cmd_name, i, seq.dqsu_t_burst[i], seq.dqsu_c_burst[i]))

            end
 
            if (i > 0 && seq.dqsu_t_burst[i] === seq.dqsu_t_burst[i-1]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQSU_TOGGLE", $sformatf("%s DQSU_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end

        end

        else begin

            if (i == 0) begin

                if ((seq.dqs_t_burst[i] !== 1'b1) ||

                    (seq.dqs_c_burst[i] !== 1'b0)) begin

                    rd_dqs_valid = 1'b0;

                    `uvm_error("DDR5_SB_RD_DQS_START", $sformatf("%s DQS DID NOT RISE OUT OF PREAMBLE DQS_T=%b DQS_C=%b", cmd_name, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))

                end

            end
 
            if (seq.dqs_t_burst[i] !== ~seq.dqs_c_burst[i]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQS_DIFF", $sformatf("%s DQS NOT DIFFERENTIAL BEAT=%0d DQS_T=%b DQS_C=%b", cmd_name, i, seq.dqs_t_burst[i], seq.dqs_c_burst[i]))

            end
 
            if (i > 0 && seq.dqs_t_burst[i] === seq.dqs_t_burst[i-1]) begin

                rd_dqs_valid = 1'b0;

                `uvm_error("DDR5_SB_RD_DQS_TOGGLE", $sformatf("%s DQS_T DID NOT TOGGLE BEAT=%0d", cmd_name, i))

            end

        end

    end

end

else begin

    rd_dqs_valid = 1'b0;

end
 
    if (rd_preamble_valid && rd_dqs_valid) begin
 
        for (int i = 0; i < 16; i++) begin
 
            col_addr = seq.col + i;
 
 
            if (mem[seq.bg][seq.ba][row].exists(col_addr)) begin
 
                expected = mem[seq.bg][seq.ba][row][col_addr];
 
                compare(seq.bg,seq.ba,row,col_addr,i,seq.dq_burst[i],expected);
 
            end

            else begin
 
                `uvm_error("DDR5_SB", $sformatf("%s ADDRESS NEVER WRITTEN BG=%0d BA=%0d ROW=%0d COL=%0d BEAT=%0d", cmd_name, seq.bg, seq.ba, row, col_addr, i))
 
            end
 
        end
 
    end

    else begin
 
        `uvm_error("DDR5_SB", $sformatf("%s DATA NOT COMPARED - INVALID PREAMBLE/DQS BG=%0d BA=%0d ROW=%0d COL=%0d", cmd_name, seq.bg, seq.ba, row, seq.col))
 
        return 1'b0;
 
    end
 
 
    return 1'b1;
 
endfunction
 
 
    function void write(ddr5_seq_item seq);
 
        bit [`ROW_WIDTH-1:0] row;

        bit [`COL_WIDTH-1:0] col_addr;

        bit [`DATA_WIDTH-1:0] expected;

    if (seq.reset_n === 1'b0) begin
 
        `uvm_info("DDR5_SB", "RESET TRANSACTION RECEIVED", UVM_LOW)
 
        clear_after_reset();
 
        return;

    end
 
 
        case (seq.cmd)
 
            // ACTIVATE
 
            ACTIVATE: begin
 
		  // tFAW (Four Activate Window) CHECK
 
current_time = seq.command_time;
 
// Remove ACTIVATE timestamps outside the tFAW window

while (activate_time.size() > 0 && (current_time - activate_time[0]) >= (`TFAW * tCK)) begin

    activate_time.pop_front();

end
 
// Maximum four ACTIVATE commands within tFAW

if (activate_time.size() >= 4) begin

    `uvm_error("DDR5_FAW_VIOLATION",

        $sformatf(

            "tFAW VIOLATION: 5th ACTIVATE within tFAW. BG=%0d BA=%0d ROW=%0d TIME=%0t OLDEST_ACT=%0t",

            seq.bg,

            seq.ba,

            seq.row,

            current_time,

            activate_time[0]

        ))

end

else begin

    `uvm_info("DDR5_FAW",

        $sformatf(

            "ACTIVATE COUNT=%0d BG=%0d BA=%0d ROW=%0d TIME=%0t",

            activate_time.size() + 1,

            seq.bg,

            seq.ba,

            seq.row,

            current_time

        ),

        UVM_LOW)

end
 
// Record the current ACTIVATE timestamp

activate_time.push_back(current_time);
 
 
                if (bank_active[seq.bg][seq.ba]) begin
 
                    `uvm_error("DDR5_SB", $sformatf("ACTIVATE ON ALREADY ACTIVE BANK BG=%0d BA=%0d ACTIVE_ROW=%0d NEW_ROW=%0d", seq.bg, seq.ba, active_row[seq.bg][seq.ba], seq.row))
 
                end

                else begin
 
                    active_row[seq.bg][seq.ba] = seq.row;

                    bank_active[seq.bg][seq.ba] = 1'b1;
 
                    `uvm_info("DDR5_SB", $sformatf("ACTIVATE BG=%0d BA=%0d ROW=%0d -> BANK OPEN", seq.bg, seq.ba, seq.row), UVM_LOW)
 
                end
 
            end

 
 
          // NORMAL WRITE
 
            WRITE: begin
 
                void'(write_common(seq, "WRITE"));

            end

            // WRITE AUTO PRECHARGE
 
            WRITE_AP: begin

                     if (write_common(seq, "WRITE_AP")) begin
 
                bank_active[seq.bg][seq.ba] = 1'b0;
 
                `uvm_info("DDR5_SB", $sformatf("WRITE_AP COMPLETE -> BANK CLOSED BG=%0d BA=%0d", seq.bg, seq.ba), UVM_LOW)
 
            end

            else begin
 
                `uvm_error("DDR5_SB", $sformatf("WRITE_AP FAILED -> BANK REMAINS OPEN BG=%0d BA=%0d", seq.bg, seq.ba))
 
            end

            end
 
            // NORMAL READ

READ: begin

    void'(read_common(seq, "READ"));

end
 
// READ WITH AUTO PRECHARGE

READ_AP: begin

    if (read_common(seq, "READ_AP")) begin

        bank_active[seq.bg][seq.ba] = 1'b0;

        active_row[seq.bg][seq.ba]  = '0;
 
        `uvm_info("DDR5_SB",

            $sformatf(

                "READ_AP DATA CHECK PASSED -> BANK CLOSED BG=%0d BA=%0d",

                seq.bg, seq.ba

            ),

            UVM_LOW)

    end

    else begin

        `uvm_error("DDR5_SB",

            $sformatf(

                "READ_AP DATA CHECK FAILED BG=%0d BA=%0d",

                seq.bg, seq.ba

            ))

    end

end


            PRECHARGE: begin

                 if (!bank_active[seq.bg][seq.ba]) begin

                        `uvm_error("DDR5_SB",

                     $sformatf("PRECHARGE ON CLOSED BANK BG=%0d BA=%0d",

                    seq.bg, seq.ba))

                 end

                else begin

                  bank_active[seq.bg][seq.ba] = 1'b0;

                     active_row[seq.bg][seq.ba]  = '0;
 
                 `uvm_info("DDR5_SB",

                     $sformatf("PRECHARGE COMPLETE BG=%0d BA=%0d",

                    seq.bg, seq.ba),

                                  UVM_LOW)

                 end

            end
 
            PRECHARGE_ALL: begin

    for (int bg = 0; bg < (1 << `BG_WIDTH); bg++) begin

        for (int ba = 0; ba < (1 << `BA_WIDTH); ba++) begin

            bank_active[bg][ba] = 1'b0;

            active_row[bg][ba]  = '0;

        end

    end
 
    `uvm_info("DDR5_SB",

      "PRECHARGE ALL: ALL BANKS CLOSED",

      UVM_LOW)

end
 
            PRECHARGE_SB: begin

    for (int bg = 0; bg < (1 << `BG_WIDTH); bg++) begin

        if (bank_active[bg][seq.ba]) begin

            bank_active[bg][seq.ba] = 1'b0;

            active_row[bg][seq.ba]  = '0;

        end

    end
 
    `uvm_info("DDR5_SB",

      $sformatf("PRECHARGE SAME BANK BA=%0d", seq.ba),

      UVM_LOW)

end
 
            default: begin
 
                `uvm_info("DDR5_SB", $sformatf("COMMAND %0d NOT PROCESSED BY SCOREBOARD", seq.cmd), UVM_DEBUG)
 
            end
 
        endcase
 
    endfunction
 
endclass : ddr5_scoreboard
 
 
 
 

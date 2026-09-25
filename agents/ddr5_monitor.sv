class ddr5_monitor extends uvm_monitor;
 
  `uvm_component_utils(ddr5_monitor)
 
  virtual ddr5_interface vif;
 
  uvm_analysis_port #(ddr5_seq_item) ddr5_ap;
 
  ddr5_seq_item tr;
 
  bit [2:0] current_rd_preamble;
  bit [1:0] current_wr_preamble;
 
  int rd_preamble_tck;
  int rd_preamble_samples;
  bit read_response_present;
 
  function new(string name = "ddr5_monitor", uvm_component parent = null);
    super.new(name, parent);
    ddr5_ap = new("ddr5_ap", this);
    current_rd_preamble = 3'b000;
  endfunction
 
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
 
    if (!uvm_config_db#(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif)) begin
      `uvm_fatal("MON", "NO INTERFACE")
    end
  endfunction
 
  task run_phase(uvm_phase phase);
    forever begin
      sample_command();
    end
  endtask
 
  task sample_command();
 
    bit [13:0] ca1;
    bit [13:0] ca2;
 
    @(vif.ddr5_mon_cb_t);
    wait(vif.ddr5_mon_cb_t.cs_n == 0);
    ca1 = vif.ddr5_mon_cb_t.ca;
 
    `uvm_info("DDR5_MON",
      $sformatf("CA1 Captured = %014b", ca1), UVM_LOW)
 
    @(vif.ddr5_mon_cb_t);
    wait(vif.ddr5_mon_cb_t.cs_n == 1);
    ca2 = vif.ddr5_mon_cb_t.ca;
 
    `uvm_info("DDR5_MON",
      $sformatf("CA2 Captured = %014b", ca2), UVM_LOW)
 
    if (ca1[4:0] != 5'b11111) begin
      decode_command(ca1, ca2);
    end
    else begin
      `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)
    end
 
  endtask
 
  task decode_command(input bit [13:0] ca1, input bit [13:0] ca2);
 
    tr = ddr5_seq_item::type_id::create("tr", this);
 
    tr.cmd = DES;
 
    if ((ca1[13:11] == 3'b000) && (ca1[1:0] == 2'b00))
      tr.cmd = ACTIVATE;
    else begin
      case (ca1[4:0])
        5'b00101: tr.cmd = MRW;
        5'b01101: tr.cmd = WRITE;
        5'b11101: tr.cmd = READ;
        5'b11111: tr.cmd = NOP;
        default: tr.cmd = DES;
      endcase
    end
 
    case (tr.cmd)
 
      NOP: begin
        `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)
      end
 
      MRW: begin
 
        tr.mra = ca1[12:5];
        tr.mr_opcode = ca2[7:0];
 
        if (tr.mra == 8'd8) begin
 
          current_rd_preamble = tr.mr_opcode[2:0];
          current_wr_preamble = tr.mr_opcode[4:3];
 
          `uvm_info("DDR5_MON",
            $sformatf("MR8 DETECTED : READ PREAMBLE MODE = %b",
                      current_rd_preamble), UVM_LOW)
 
        end
 
        `uvm_info("DDR5_MON",
          $sformatf("MRW : MRA=%0d DATA=%0d",
                    tr.mra, tr.mr_opcode), UVM_LOW)
 
        ddr5_ap.write(tr);
 
      end
 
      WRITE: begin
 
        tr.bg = ca1[10:8];
        tr.ba = ca1[7:6];
        tr.col[10:3] = ca2[8:1];
        tr.col[2:0] = 3'b000;
        tr.wr_preamble = current_wr_preamble;
 
        `uvm_info("DDR5_MON",
          $sformatf("WRITE : BG=%0d BA=%0d COL=%0d",
                    tr.bg, tr.ba, tr.col), UVM_LOW)
 
        sample_write_data(tr);
 
        `uvm_info("MON_SB",
          "Sending WRITE transaction to scoreboard", UVM_LOW)
 
        ddr5_ap.write(tr);
 
      end
 
      READ: begin
 
        tr.bg = ca1[10:8];
        tr.ba = ca1[7:6];
        tr.col[10:3] = ca2[8:1];
        tr.col[2:0] = 3'b000;
        tr.rd_preamble = current_rd_preamble;
 
        `uvm_info("DDR5_MON",$sformatf("READ : BG=%0d BA=%0d COL=%0d",
             tr.bg, tr.ba, tr.col), UVM_LOW)
 
        sample_read_data(tr);
 
        `uvm_info("MON_SB",
          "Sending READ transaction to scoreboard", UVM_LOW)
 
        ddr5_ap.write(tr);
 
      end
 
      ACTIVATE: begin
 
        tr.bg = ca1[10:8];
        tr.ba = ca1[7:6];
        tr.row[3:0] = ca1[5:2];
        tr.row[17:4] = ca2;
 
        `uvm_info("DDR5_MON",
          $sformatf("ACTIVATE : BG=%0d BA=%0d ROW=%0d",
                    tr.bg, tr.ba, tr.row), UVM_LOW)
 
        ddr5_ap.write(tr);
 
      end
 
      default: begin
 
        `uvm_warning("DDR5_MON",
          $sformatf("DES CMD : CA1=%014b CA2=%014b",
                    ca1, ca2))
 
      end
 
    endcase
 
  endtask
 
  task sample_write_data(ddr5_seq_item tr);
 
    int preamble_tck;
    int preamble_samples;
    int preamble_wait_cycles;
    int dq_wait_cycles;
 
    case (current_wr_preamble)
 
      WR_PRE_2TCK: preamble_tck = 2;
      WR_PRE_3TCK: preamble_tck = 3;
      WR_PRE_4TCK: preamble_tck = 4;
 
      default: begin
        preamble_tck = 2;
        `uvm_warning("DDR5_MON",
          "Invalid WR preamble. Using 2TCK")
      end
 
    endcase
 
    preamble_samples = 2 * preamble_tck;
 
    case (current_wr_preamble)
 
      WR_PRE_2TCK:
        preamble_wait_cycles = `TCWL - 2;
 
      WR_PRE_3TCK:
        preamble_wait_cycles = `TCWL - 3;
 
      WR_PRE_4TCK:
        preamble_wait_cycles = `TCWL - 4;
 
      default:
        preamble_wait_cycles = `TCWL - 2;
 
    endcase
 
    dq_wait_cycles = `TCWL;
 
    `uvm_info("WRITE_TIMING",
      $sformatf("WR_PRE=%0d PRE_WAIT=%0d DQ_WAIT=%0d",
                preamble_tck,
                preamble_wait_cycles,
                dq_wait_cycles), UVM_LOW)
 
    fork
 
      begin : PREAMBLE_THREAD
 
        repeat (preamble_wait_cycles)
          @(vif.ddr5_mon_cb_t);
 
        for (int i = 0; i < preamble_samples; i++) begin
 
          if ((i % 2) == 0) begin
 
            @(vif.ddr5_mon_pre_t_cb);
 
            tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_t;
            tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_c;
 
            `uvm_info("WR_PRE",
              $sformatf("PREAMBLE[%0d] T : DQS_T=%0b DQS_C=%0b",
                        i,
                        tr.dqs_t_preamble[i],
                        tr.dqs_c_preamble[i]), UVM_LOW)
 
          end
          else begin
 
            @(vif.ddr5_mon_pre_c_cb);
 
            tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_t;
            tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_c;
 
            `uvm_info("WR_PRE",
              $sformatf("PREAMBLE[%0d] C : DQS_T=%0b DQS_C=%0b",
                        i,
                        tr.dqs_t_preamble[i],
                        tr.dqs_c_preamble[i]), UVM_LOW)
 
          end
 
        end
 
        `uvm_info("WR_PRE",
          "WRITE DQS PREAMBLE COMPLETE", UVM_LOW)
 
      end
 
      begin : DQ_THREAD
 
        repeat (dq_wait_cycles)
          @(vif.ddr5_mon_cb_t);
 
        `uvm_info("WRITE_DQ",
          "DQ MONITOR THREAD ACTIVE - FIRST DQ SAMPLE POINT REACHED",
          UVM_LOW)
 
        @(vif.ddr5_mon_dqs_t_cb);
 
        tr.dq_burst[0] = vif.ddr5_mon_dqs_t_cb.dq;
        tr.dqs_t_burst[0] = vif.ddr5_mon_dqs_t_cb.dqs_t;
        tr.dqs_c_burst[0] = vif.ddr5_mon_dqs_t_cb.dqs_c;
 
        `uvm_info("WRITE_DQ",
          $sformatf("WRITE[0] DQ=%0d DQS_T=%b DQS_C=%b",
                    tr.dq_burst[0],
                    tr.dqs_t_burst[0],
                    tr.dqs_c_burst[0]), UVM_LOW)
 
        for (int i = 1; i < 16; i++) begin
 
          if ((i % 2) == 1) begin
 
            @(vif.ddr5_mon_dqs_c_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqs_c_cb.dq;
            tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_t;
            tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_c;
 
          end
          else begin
 
            @(vif.ddr5_mon_dqs_t_cb);
 
            tr.dq_burst[i] = vif.ddr5_mon_dqs_t_cb.dq;
            tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_t;
            tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_c;
 
          end
 
          `uvm_info("WRITE_DQ",
            $sformatf("WRITE[%0d] DQ=%0d DQS_T=%b DQS_C=%b",
                      i,
                      tr.dq_burst[i],
                      tr.dqs_t_burst[i],
                      tr.dqs_c_burst[i]), UVM_LOW)
 
        end
 
      end
 
    join
 
    `uvm_info("WRITE_DQ",
      "ALL 16 WRITE DQ BEATS CAPTURED", UVM_LOW)
 
  endtask
 
  function void get_rd_preamble_info();
 
    rd_preamble_tck = 0;
    rd_preamble_samples = 0;
 
    case (current_rd_preamble)
 
      3'b000: begin
        rd_preamble_tck = 1;
      end
 
      3'b001: begin
        rd_preamble_tck = 2;
      end
 
      3'b010: begin
        rd_preamble_tck = 2;
      end
 
      3'b011: begin
        rd_preamble_tck = 3;
      end
 
      3'b100: begin
        rd_preamble_tck = 4;
      end
 
      default: begin
 
        `uvm_warning("DDR5_MON",
          $sformatf("Unsupported RD preamble mode = %b",
                    current_rd_preamble))
 
        rd_preamble_tck = 0;
 
      end
 
    endcase
 
    rd_preamble_samples = 2 * rd_preamble_tck;
 
  endfunction
 
  task sample_read_data(ddr5_seq_item tr);
 
    int wait_cycles;
 
    get_rd_preamble_info();
 
    `uvm_info("READ_DEBUG",
      $sformatf("READ PREAMBLE MODE=%b PREAMBLE=%0d tCK TCL=%0d",
                current_rd_preamble,
                rd_preamble_tck,
                `TCL), UVM_LOW)
 
    wait_cycles = `TCL - rd_preamble_tck;
 
    if (wait_cycles < 0) begin
 
      `uvm_error("DDR5_MON",
        $sformatf("Invalid timing: TCL=%0d PREAMBLE=%0d",
                  `TCL,
                  rd_preamble_tck))
 
      return;
 
    end
 
    repeat (wait_cycles) begin
      @(vif.ddr5_mon_cb_t);
    end
 
    for (int i = 0; i < rd_preamble_samples; i++) begin
 
      if ((i % 2) == 0) begin
 
        @(vif.ddr5_mon_cb_t);
 
        tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_t.dqs_t;
        tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_t.dqs_c;
 
        `uvm_info("DDR5_MON_RD_PRE",
          $sformatf("PREAMBLE[%0d] T : DQS_T=%b DQS_C=%b",
                    i,
                    tr.dqs_t_preamble[i],
                    tr.dqs_c_preamble[i]), UVM_LOW)
 
      end
      else begin
 
        @(vif.ddr5_mon_cb_c);
 
        tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_c.dqs_t;
        tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_c.dqs_c;
 
        `uvm_info("DDR5_MON_RD_PRE",
          $sformatf("PREAMBLE[%0d] C : DQS_T=%b DQS_C=%b",
                    i,
                    tr.dqs_t_preamble[i],
                    tr.dqs_c_preamble[i]), UVM_LOW)
 
      end
 
    end
 
    read_response_present = 1'b1;
 
    for (int i = 0; i < rd_preamble_samples; i++) begin
 
      if ((tr.dqs_t_preamble[i] !== 1'b0 &&
           tr.dqs_t_preamble[i] !== 1'b1) ||
          (tr.dqs_c_preamble[i] !== 1'b0 &&
           tr.dqs_c_preamble[i] !== 1'b1)) begin
 
        read_response_present = 1'b0;
        break;
 
      end
 
    end
 
    if (!read_response_present) begin
 
      `uvm_info("DDR5_MON",
        "NO READ DQS PREAMBLE DETECTED - FILLING ALL 16 READ BEATS WITH X",
        UVM_LOW)
 
      for (int i = 0; i < 16; i++) begin
 
        tr.dqs_t_burst[i] = 1'bx;
        tr.dqs_c_burst[i] = 1'bx;
        tr.dq_burst[i] = 'x;
 
        `uvm_info("DDR5_MON",
          $sformatf("READ[%0d] DQS_T=X DQS_C=X DQ=X", i),
          UVM_LOW)
 
      end
 
    end
    else begin
 
      `uvm_info("DDR5_MON",
        "READ DQS PREAMBLE DETECTED - STARTING BL16 DQ SAMPLING",
        UVM_LOW)
 
      for (int i = 0; i < 16; i++) begin
 
        if ((i % 2) == 0) begin
 
          @(vif.ddr5_mon_dqs_t_cb);
 
          tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_t;
          tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_c;
          tr.dq_burst[i] = vif.ddr5_mon_dqs_t_cb.dq;
 
        end
        else begin
 
          @(vif.ddr5_mon_dqs_c_cb);
 
          tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_t;
          tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_c;
          tr.dq_burst[i] = vif.ddr5_mon_dqs_c_cb.dq;
 
        end
 
        `uvm_info("DDR5_MON_READ_DQ",
          $sformatf("READ[%0d] DQS_T=%b DQS_C=%b DQ=%0h",
                    i,
                    tr.dqs_t_burst[i],
                    tr.dqs_c_burst[i],
                    tr.dq_burst[i]), UVM_LOW)
 
      end
 
    end
 
    `uvm_info("READ_DEBUG",
      "READ PREAMBLE CHECK AND RESPONSE CAPTURE COMPLETE",
      UVM_LOW)
 
  endtask
 
endclass

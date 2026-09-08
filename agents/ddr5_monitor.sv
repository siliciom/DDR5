class ddr5_monitor extends uvm_monitor;

  `uvm_component_utils(ddr5_monitor)

  // Interface
  virtual ddr5_interface vif;

  // Analysis Port
  uvm_analysis_port #(ddr5_seq_item) ddr5_ap;

  // Transaction
  ddr5_seq_item tr;
 
  // Current READ preamble configuration from MR8 OP[2:0]
  bit [2:0] current_rd_preamble;
  bit [1:0] current_wr_preamble;

  // Calculated READ preamble information
  int rd_preamble_tck;
  int rd_preamble_samples;

  // Constructor
  function new(string name = "ddr5_monitor", uvm_component parent = null);
    super.new(name, parent);
    ddr5_ap = new("ddr5_ap", this);
     current_rd_preamble = 3'b000;
     //current_wr_preamble=WR_PRE_2TCK;
  endfunction

  // Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif)) begin
      `uvm_fatal("MON", "NO INTERFACE")
    end
  endfunction

  // Run Phase
  task run_phase(uvm_phase phase);
    forever begin
      sample_command();
    end
  endtask


  // Sample Command
  task sample_command();
    bit [13:0] ca1;
    bit [13:0] ca2;

    // CA1
    @(vif.ddr5_mon_cb_t);
    wait(vif.ddr5_mon_cb_t.cs_n == 0);
    ca1 = vif.ddr5_mon_cb_t.ca;
    `uvm_info("DDR5_MON", $sformatf("CA1 Captured = %014b", ca1), UVM_LOW)

    // CA2
    @(vif.ddr5_mon_cb_t);
    wait(vif.ddr5_mon_cb_t.cs_n == 1);
    ca2 = vif.ddr5_mon_cb_t.ca;
    `uvm_info("DDR5_MON", $sformatf("CA2 Captured = %014b", ca2), UVM_LOW)

    // NOP
    if (ca1[4:0] != 5'b11111) begin
      decode_command(ca1, ca2);
    end
    else begin
      `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)
    end
  endtask

  // Command Decoder
  task decode_command(input bit [13:0] ca1, input bit [13:0] ca2);

  tr = ddr5_seq_item::type_id::create("tr", this);

  // Step 1: Identify command
  tr.cmd = DES;

  // ACTIVATE has a different CA encoding, so check it first
  if ((ca1[13:11] == 3'b000) && (ca1[1:0] == 2'b00))
    tr.cmd = ACTIVATE;
  else begin
    case (ca1[4:0])
      5'b00101: tr.cmd = MRW;
      5'b01101: tr.cmd = WRITE;
      5'b11101: tr.cmd = READ;
      5'b11111: tr.cmd = NOP;

      default:   tr.cmd = DES;

    endcase
  end

  // Step 2: Decode command-specific fields
  case (tr.cmd)

    // NOP
    NOP: begin

      `uvm_info("DDR5_MON", "NOP COMMAND DETECTED", UVM_LOW)

    end

    // MRW
    MRW: begin

      tr.mra       = ca1[12:5];
      tr.mr_opcode = ca2[7:0];

      if (tr.mra == 8'd8) begin

        current_rd_preamble = tr.mr_opcode[2:0];
	 current_wr_preamble = tr.mr_opcode[4:3];

        `uvm_info("DDR5_MON", $sformatf("MR8 DETECTED : READ PREAMBLE MODE = %b", current_rd_preamble), UVM_LOW)

      end

      `uvm_info("DDR5_MON", $sformatf("MRW : MRA=%0d DATA=%0d", tr.mra, tr.mr_opcode), UVM_LOW)

      ddr5_ap.write(tr);

    end

    // WRITE
    WRITE: begin

      tr.bg        = ca1[10:8];
      tr.ba        = ca1[7:6];
      tr.col[10:3] = ca2[8:1];
      tr.col[2:0]  = 3'b000;
      tr.wr_preamble = current_wr_preamble;


      `uvm_info("DDR5_MON", $sformatf("WRITE : BG=%0d BA=%0d COL=%0d", tr.bg, tr.ba, tr.col), UVM_LOW)

      // Capture BL16 write data
      sample_write_data(tr);

      `uvm_info("MON_SB", "Sending WRITE transaction to scoreboard", UVM_LOW)

      ddr5_ap.write(tr);

    end

    // READ
    READ: begin

      tr.bg        = ca1[10:8];
      tr.ba        = ca1[7:6];
      tr.col[10:3] = ca2[8:1];
      tr.col[2:0]  = 3'b000;
      tr.rd_preamble = current_wr_preamble;


      `uvm_info("DDR5_MON", $sformatf("READ : BG=%0d BA=%0d COL=%0d", tr.bg, tr.ba, tr.col), UVM_LOW)

      // Capture READ preamble + BL16 data
      sample_read_data(tr);

      `uvm_info("MON_SB", "Sending READ transaction to scoreboard", UVM_LOW)

      ddr5_ap.write(tr);

    end

    // ACTIVATE
    ACTIVATE: begin

      tr.bg        = ca1[10:8];
      tr.ba        = ca1[7:6];
      tr.row[3:0]  = ca1[5:2];
      tr.row[17:4] = ca2;

      `uvm_info("DDR5_MON", $sformatf("ACTIVATE : BG=%0d BA=%0d ROW=%0d", tr.bg, tr.ba, tr.row), UVM_LOW)

      ddr5_ap.write(tr);

    end

    // UNKNOWN
    default: begin

     `uvm_warning("DDR5_MON", $sformatf("DES CMD : CA1=%014b CA2=%014b", ca1, ca2))

    end

  endcase

endtask

task sample_write_data(ddr5_seq_item tr);
//begin

  int preamble_tck;
  int preamble_samples;
  int wait_cycles;

  case (current_wr_preamble)
    WR_PRE_2TCK: preamble_tck = 2;//0010
    WR_PRE_3TCK: preamble_tck = 3;//000010
    WR_PRE_4TCK: preamble_tck = 4;
    default:     preamble_tck = 2;
  endcase

  preamble_samples = 2 * preamble_tck;
  wait_cycles      = `TCWL - preamble_tck;

`uvm_info("WRITE_DEBUG",$sformatf("[$time=%0t] WRITE DATA SAMPLING START | WR_PRE=%0d PREAMBLE_TCK=%0d TCWL=%0d WAIT_CYCLES=%0d",$time,current_wr_preamble,preamble_tck,`TCWL,wait_cycles),UVM_LOW)

repeat (wait_cycles+1) begin
  @(vif.ddr5_mon_cb_t);
  `uvm_info("WRITE_TIMING",$sformatf("[$time=%0t] WAIT CYCLE",$time),UVM_LOW)
end

`uvm_info("WRITE_TIMING",$sformatf("[$time=%0t] WAIT COMPLETE - WAITING FOR FIRST DQS",$time),UVM_LOW)
for (int i = 0; i < preamble_samples; i++) begin
 if ((i % 2) == 0) begin
   // @(vif.ddr5_mon_dqs_t_cb);
   // @(vif.ddr5_mon_cb_t or vif.ddr5_mon_cb_c );
     @(vif.ddr5_mon_cb_t); // posedge clk
    tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_t;
    tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_t_cb.dqs_c;
    `uvm_info("DDR5_MON_WR_PRE",$sformatf(" WR_PRE[%0d]| DQS_T=%b DQS_C=%b",i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
   // `uvm_info("DDR5_MON_WR_PRE",$sformatf("WR_PRE[%0d]| DQS_T=%b DQS_C=%b",i,vif.ddr5_drv_cb_t.dqs_t,vif.ddr5_drv_cb_t.dqs_c),UVM_LOW)
  end
 else begin
    //@(vif.ddr5_mon_dqs_c_cb);
     @(vif.ddr5_mon_cb_c); // posedge clk
    tr.dqs_t_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_t;
   tr.dqs_c_preamble[i] = vif.ddr5_mon_pre_c_cb.dqs_c;
    `uvm_info("DDR5_MON_WR_PRE",$sformatf("[$time=%0t] WR_PRE[%0d] C EDGE | DQS_T=%b DQS_C=%b",$time,i,tr.dqs_t_preamble[i],tr.dqs_c_preamble[i]),UVM_LOW)
   // `uvm_info("DDR5_MON_WR_PRE",$sformatf("WR_PRE[%0d]| DQS_T=%b DQS_C=%b",i,vif.ddr5_drv_cb_c.dqs_t,vif.ddr5_drv_cb_c.dqs_c),UVM_LOW)
  end
end

`uvm_info("WRITE_TIMING",$sformatf("[$time=%0t] PREAMBLE SAMPLING END",$time),UVM_LOW)

`uvm_info("WRITE_TIMING",$sformatf("[$time=%0t] BL16 DATA SAMPLING START",$time),UVM_LOW)

for (int i = 0; i < 16; i++) begin
  if ((i % 2) == 0) begin
    @(vif.ddr5_mon_dqs_t_cb);
    tr.dq_burst[i] = vif.ddr5_mon_dqs_t_cb.dq;
    tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_t;
    tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_t_cb.dqs_c;
    `uvm_info("DDR5_MON_WRITE_DQ",$sformatf("[$time=%0t] WRITE[%0d] T EDGE | DQS_T=%b DQS_C=%b DQ=%0d",$time,i,tr.dqs_t_burst[i],tr.dqs_c_burst[i],tr.dq_burst[i]),UVM_LOW)
  end
  else begin
    @(vif.ddr5_mon_dqs_c_cb);
    tr.dq_burst[i] = vif.ddr5_mon_dqs_c_cb.dq;
    tr.dqs_t_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_t;
    tr.dqs_c_burst[i] = vif.ddr5_mon_dqs_c_cb.dqs_c;
    `uvm_info("DDR5_MON_WRITE_DQ",$sformatf("[$time=%0t] WRITE[%0d] C EDGE | DQS_T=%b DQS_C=%b DQ=%0d",$time,i,tr.dqs_t_burst[i],tr.dqs_c_burst[i],tr.dq_burst[i]),UVM_LOW)
  end
end
//end
`uvm_info("WRITE_TIMING",$sformatf("[$time=%0t] BL16 DATA SAMPLING END",$time),UVM_LOW)
endtask

// Get READ preamble length from MR8 OP[2:0]
  function void get_rd_preamble_info();

    rd_preamble_tck     = 0;
    rd_preamble_samples = 0;

    case (current_rd_preamble)

      // 1 tCK preamble
      3'b000: begin
        rd_preamble_tck = 1;
      end

      // 2 tCK preamble
      3'b001: begin
        rd_preamble_tck = 2;
      end

      // 2 tCK preamble
      3'b010: begin
        rd_preamble_tck = 2;
      end

      // 3 tCK preamble
      3'b011: begin
        rd_preamble_tck = 3;
      end

      // 4 tCK preamble
      3'b100: begin
        rd_preamble_tck = 4;
      end

      default: begin

        `uvm_warning("DDR5_MON",$sformatf("Unsupported RD preamble mode = %b",current_rd_preamble ))

        rd_preamble_tck = 0;

      end

    endcase

    // Each tCK has T and C sampling positions
    rd_preamble_samples = 2 * rd_preamble_tck;

  endfunction
  // READ PREAMBLE + BL16 DATA SAMPLING
task sample_read_data(ref ddr5_seq_item tr);

  int wait_cycles;

  // Get read preamble timing from MR8 configuration
  get_rd_preamble_info();

  `uvm_info("READ_DEBUG", $sformatf("READ PREAMBLE MODE=%b PREAMBLE=%0d tCK TCL=%0d", current_rd_preamble, rd_preamble_tck, `TCL), UVM_LOW)

  // Wait until read preamble starts
  wait_cycles = `TCL - rd_preamble_tck;

  if (wait_cycles < 0) begin
    `uvm_error("DDR5_MON", $sformatf("Invalid timing: TCL=%0d PREAMBLE=%0d", `TCL, rd_preamble_tck))
    return;
  end

  repeat (wait_cycles) begin
    @(vif.ddr5_mon_cb_t);
  end

  // Sample read preamble from DUT
  for (int i = 0; i < rd_preamble_samples; i++) begin

    if ((i % 2) == 0) begin

      @(vif.ddr5_mon_cb_t);

      tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_t.dqs_t;
      tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_t.dqs_c;

      `uvm_info("DDR5_MON_RD_PRE", $sformatf("PREAMBLE[%0d] T : DQS_T=%b DQS_C=%b", i, tr.dqs_t_preamble[i], tr.dqs_c_preamble[i]), UVM_LOW)

    end
    else begin

      @(vif.ddr5_mon_cb_c);

      tr.dqs_t_preamble[i] = vif.ddr5_mon_cb_c.dqs_t;
      tr.dqs_c_preamble[i] = vif.ddr5_mon_cb_c.dqs_c;

      `uvm_info("DDR5_MON_RD_PRE", $sformatf("PREAMBLE[%0d] C : DQS_T=%b DQS_C=%b", i, tr.dqs_t_preamble[i], tr.dqs_c_preamble[i]), UVM_LOW)

    end

  end

  // Sample BL16 read data using DQS edges
  for (int i = 0; i < 16; i++) begin

    if ((i % 2) == 0) begin

      @(posedge vif.ck_t);

      tr.dqs_t_burst[i] = vif.dqs_t;
      tr.dqs_c_burst[i] = vif.dqs_c;
      tr.dq_burst[i]    = vif.dq;

    end
    else begin

      @(posedge vif.ck_c);

      tr.dqs_t_burst[i] = vif.dqs_t;
      tr.dqs_c_burst[i] = vif.dqs_c;
      tr.dq_burst[i]    = vif.dq;

    end

    `uvm_info("DDR5_MON_READ_DQ", $sformatf("READ[%0d] DQS_T=%b DQS_C=%b DQ=%0h", i, tr.dqs_t_burst[i], tr.dqs_c_burst[i], tr.dq_burst[i]), UVM_LOW)

  end

  `uvm_info("READ_DEBUG", "READ PREAMBLE + ALL 16 READ DATA BEATS CAPTURED", UVM_LOW)

endtask
endclass


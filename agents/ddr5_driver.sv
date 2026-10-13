class ddr5_driver extends uvm_driver #(ddr5_seq_item);

  `uvm_component_utils(ddr5_driver)

  // Interface

  virtual ddr5_interface vif;

  ddr5_seq_item seq;
  int faw_count = 0;

  // Constructor

  function new(string name = "ddr5_driver", uvm_component parent);

    super.new(name, parent);

  endfunction

  // Build Phase

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db#(virtual ddr5_interface)::get(this, "", "ddr5_interface", vif)) begin

      `uvm_fatal("DRV", "NO INTERFACE")

    end

  endfunction

  // Run Phase

  task run_phase(uvm_phase phase);

    seq_item_port.get_next_item(seq);

    ddr5_initialize();

    drive_tx(seq);

    seq_item_port.item_done();

    forever begin

      seq_item_port.get_next_item(seq);

      drive_tx(seq);

      seq_item_port.item_done();

    end

  endtask

  // Bus Initialization

  task bus_init;

    @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.ca    <= 1'bz;

    vif.ddr5_dq_drv_cb_t.dq    <= 1'bz;

    vif.ddr5_wr_drv_cb_t.dqs_t <= 0;

    vif.ddr5_wr_drv_cb_t.dqs_c <= 0;

    vif.ddr5_drv_cb_t.dm_n  <= 0;

  endtask

  // DDR5 Initialization

  task ddr5_initialize();

    bus_init();

    reset_sequence();

    nop();

    configure_mode_registers();

  endtask

  // Reset Sequence

  task reset_sequence();

    vif.ddr5_drv_cb_t.reset_n <= 1'b0;

    vif.ddr5_drv_cb_t.cs_n    <= 1'b0;

    vif.ddr5_drv_cb_t.ca      <= 1'bz;

    repeat(`TINIT1)

      @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.reset_n <= 1'b1;

    repeat(`TINIT3)

      @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.cs_n <= 1'b1;

    vif.ddr5_drv_cb_t.ca   <= 1'bz;

    repeat(`TINIT4)

      @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.ca <= 1'bz;

  endtask

  // Mode Register Configuration

  bit [7:0] mr_cfg [bit [7:0]];

  task configure_mode_registers();

    mr_cfg[8'd0] = {1'b0, seq.rl, seq.bl};

    mr_cfg[8'd5] = {2'b00,

                    seq.dm_cfg,

                    5'b00000};

    mr_cfg[8'd6] = {seq.trp_cfg,

                    seq.wr_recovery};

    mr_cfg[8'd8] = {seq.wr_postamble,

                    seq.rd_postamble,

                    1'b0,

                    seq.wr_preamble,

                    seq.rd_preamble};

    mr_cfg[8'd50] = {7'b0000000,

                     seq.crc_en};

    foreach (mr_cfg[mra]) begin

      mrw(mra, mr_cfg[mra]);

    end

  endtask

  // Command Drive

  task drive_cmd(input bit cs, input bit [13:0] ca);

    @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.cs_n <= cs;

   vif.ddr5_drv_cb_t.ca   <= ca;

  endtask

  // Release CA

  task release_ca();

    @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.ca   <= 1'bz;

    vif.ddr5_drv_cb_t.cs_n <= 1'b1;

  endtask

  // NOP

  task nop();

    bit [13:0] ca;

    ca = {9'b000000000, 5'b11111};

    drive_cmd(1'b0, ca);

    repeat(`TINIT5)

      @(vif.ddr5_drv_cb_t);

    vif.ddr5_drv_cb_t.ca <= 1'bz;

  endtask

  bit [1:0] current_wr_preamble;

  bit       current_wr_postamble;


  event preamble_done_ev;

  // Mode Register Write

  task mrw(input bit [7:0] mra, input bit [7:0] mr_opcode);

    bit [13:0] ca1, ca2;

    ca1 = {1'b0, mra, 5'b00101};

    ca2 = {6'b000000, mr_opcode};

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

    if (mra == 8'd8) begin

      current_wr_preamble  = mr_opcode[4:3];

      current_wr_postamble = mr_opcode[7];

      `uvm_info("DDR5_DRV", $sformatf("MR8 UPDATED WR_PRE=%b WR_POST=%b", current_wr_preamble, current_wr_postamble), UVM_LOW)

    end

    repeat(`TMRD) @(vif.ddr5_drv_cb_t);

  endtask

  // Mode Register Read

  task mrr(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    ca1 = {1'b0, seq.mra, 5'b10101};

    ca2 = '0;

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

  endtask

  // Activate

  task activate(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    `uvm_info("DDR5_DRV", $sformatf("ACTIVATE BG=%0d BA=%0d ROW=%0d", seq.bg, seq.ba, seq.row), UVM_LOW)

    ca1 = {3'b000, seq.bg, seq.ba, seq.row[3:0], 2'b00};

    ca2 = seq.row[17:4];

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

  endtask

  task drive_1ck_zero();

    bit dqs_t_val = 1'b0;

    bit dqs_c_val = 1'b1;

    @(vif.ddr5_drv_cb_t);

    vif.ddr5_wr_drv_cb_t.dqs_t <= dqs_t_val;

    vif.ddr5_wr_drv_cb_t.dqs_c <= dqs_c_val;

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] PREAMBLE T: DQS_T=%b DQS_C=%b",$time,dqs_t_val,dqs_c_val),UVM_LOW)

    @(vif.ddr5_drv_cb_c);

    vif.ddr5_wr_drv_cb_c.dqs_t <= dqs_t_val;

    vif.ddr5_wr_drv_cb_c.dqs_c <= dqs_c_val;

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] PREAMBLE C: DQS_T=%b DQS_C=%b",$time,dqs_t_val,dqs_c_val),UVM_LOW)

  endtask

  task drive_1ck_onezero();

    bit dqs_t_val;

    bit dqs_c_val;

    @(vif.ddr5_drv_cb_t);

    dqs_t_val = 1'b1;

    dqs_c_val = 1'b0;

    vif.ddr5_wr_drv_cb_t.dqs_t <= dqs_t_val;

    vif.ddr5_wr_drv_cb_t.dqs_c <= dqs_c_val;

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] PREAMBLE T: DQS_T=%b DQS_C=%b",$time,dqs_t_val,dqs_c_val),UVM_LOW)

    @(vif.ddr5_drv_cb_c);

    dqs_t_val = 1'b0;

    dqs_c_val = 1'b1;

    vif.ddr5_wr_drv_cb_c.dqs_t <= dqs_t_val;

    vif.ddr5_wr_drv_cb_c.dqs_c <= dqs_c_val;

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] PREAMBLE C: DQS_T=%b DQS_C=%b",$time,dqs_t_val,dqs_c_val),UVM_LOW)

  endtask

  // Write Preamble

  task drive_write_preamble(bit [1:0] wr_preamble);

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] WRITE PREAMBLE START WR_PRE=%0d",$time,wr_preamble),UVM_LOW)

    case (wr_preamble)

      // 2 tCK  : 0010

      WR_PRE_2TCK: begin

        repeat (`TCWL - 3) @(vif.ddr5_drv_cb_t);

        // 0010 pattern

        drive_1ck_zero();

        drive_1ck_onezero();

      end

      // 3 tCK  : 000010

      WR_PRE_3TCK: begin

        repeat (`TCWL - 4)@(vif.ddr5_drv_cb_t);

        // 000010 pattern

        repeat (2)

          drive_1ck_zero();

        drive_1ck_onezero();

      end

      // 4 tCK : 00001010

      WR_PRE_4TCK: begin

        repeat (`TCWL - 5)@(vif.ddr5_drv_cb_t);

        repeat (2)

          drive_1ck_zero();

        repeat (2)

          drive_1ck_onezero();

      end

      default: begin

        repeat (`TCWL - 3)

          @(vif.ddr5_drv_cb_t);

        // Default 2 tCK preamble : 0010

        drive_1ck_zero();

        drive_1ck_onezero();

      end

    endcase

    `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] WRITE PREAMBLE END",$time),UVM_LOW)


    -> preamble_done_ev;

  endtask

  // Write

  task write(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    bit cmd_bl;

    if ((seq.bl == BC8_OTF) || (seq.bl == BL32_OTF))

      cmd_bl = 1'b1;

    else

      cmd_bl = 1'b0;

    ca1 = {3'b000, seq.bg, seq.ba, cmd_bl, 5'b01101};

    ca2 = {3'b000, 1'b1, 1'b0, seq.col[10:3], 1'b0};

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

    `uvm_info("DDR5_DRV", $sformatf("WRITE BG=%0d BA=%0d COL=%0d CA1=%014d", seq.bg, seq.ba, seq.col, ca1), UVM_LOW)

/*

    fork

      // Branch 1: DQS Preamble

      drive_write_preamble(current_wr_preamble);
 
      // Branch 2: BL16 Data

      begin

   //  repeat (`TCWL-2) @ (vif.ddr5_drv_cb_t);

        `uvm_info("DRV_WR_TIMING",$sformatf("[$time=%0t] BL16 DATA START",$time),UVM_LOW)

        for (int i = 0; i < 16; i++) begin
 
            @(vif.ddr5_dq_drv_cb_t);

            vif.ddr5_dq_drv_cb_t.dq    <= seq.dq_burst[i];

            vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b1;

            vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

            `uvm_info("DDR5_DRV", $sformatf("DQS_T RISE -> DQ_BURST[%0d] = %0d", i, seq.dq_burst[i]), UVM_LOW)

          end

          else begin

            @(vif.ddr5_dq_drv_cb_c);

            vif.ddr5_dq_drv_cb_c.dq    <= seq.dq_burst[i];

            vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0;

            vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

            `uvm_info("DDR5_DRV", $sformatf("DQS_C RISE -> DQ_BURST[%0d] = %0d", i, seq.dq_burst[i]), UVM_LOW)

          end
 
        end

	`uvm_info("DQSDdddddddBG",$sformatf("BL16 COMPLETE time=%0t",$time),UVM_LOW)

      //end

      end

    join

*/

fork
 
  // DQS Preamble

  drive_write_preamble(current_wr_preamble);
 
  // DQ thread

  begin

    repeat(`TCWL-2)

      @(vif.ddr5_drv_cb_t);   // 19 clocks
 
    for(int i=0;i<16;i++) begin
 
      if((i%2)==0) begin

        @(vif.ddr5_dq_drv_cb_t);

        vif.ddr5_dq_drv_cb_t.dq <= seq.dq_burst[i];

            `uvm_info("DDR5_DRV", $sformatf("DQS_T RISE -> DQ_BURST[%0d] = %0d", i, seq.dq_burst[i]), UVM_LOW)

      end

      else begin

        @(vif.ddr5_dq_drv_cb_c);

        vif.ddr5_dq_drv_cb_c.dq <= seq.dq_burst[i];

            `uvm_info("DDR5_DRV", $sformatf("DQS_T RISE -> DQ_BURST[%0d] = %0d", i, seq.dq_burst[i]), UVM_LOW)

      end
 
    end
 
    // Release DQ after the final data sampling opportunity
 
         @(vif.ddr5_dq_drv_cb_t);
 
          vif.ddr5_dq_drv_cb_t.dq <= 'z;

  end
 
  // DQS thread

  begin

    repeat(`TCWL-1)

      @(vif.ddr5_drv_cb_t);   // 20 clocks
 
    for(int i=0;i<16;i++) begin
 
      if((i%2)==0) begin

        @(vif.ddr5_wr_drv_cb_t);

        vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b1;

        vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b0;

      end

      else begin

        @(vif.ddr5_wr_drv_cb_c);

        vif.ddr5_wr_drv_cb_c.dqs_t <= 1'b0;

        vif.ddr5_wr_drv_cb_c.dqs_c <= 1'b1;

      end
 
    end

  end
 
join

    // Write Postamble

    @(vif.ddr5_drv_cb_t);

    `uvm_info("DQSDBbbbbbbbbG",$sformatf("POSTAMBLE START time=%0t",$time),UVM_LOW)

   // vif.ddr5_dq_drv_cb_t.dq    <= 'z;

    vif.ddr5_wr_drv_cb_t.dqs_t <= 1'b0;

    vif.ddr5_wr_drv_cb_t.dqs_c <= 1'b1;

    if (current_wr_postamble == WR_PSTBLE_0_5TCK) begin

      @(vif.ddr5_drv_cb_c);

    end

    else if (current_wr_postamble == WR_PSTBLE_1_5TCK) begin

      @(vif.ddr5_drv_cb_c);

      @(vif.ddr5_drv_cb_t);

      @(vif.ddr5_drv_cb_c);

    end

    // Final Release

    `uvm_info("DQfinal releaseeeeeeeeeeeeeeeeSDBG",$sformatf("RELEASE DQS time=%0t",$time),UVM_LOW)

    vif.ddr5_dq_drv_cb_t.dq    <= 'z;

    vif.ddr5_wr_drv_cb_t.dqs_t <= 'z;

    vif.ddr5_wr_drv_cb_c.dqs_c <= 'z;

    vif.ddr5_dq_drv_cb_c.dq    <= 'z;

    vif.ddr5_wr_drv_cb_c.dqs_t <= 'z;

    vif.ddr5_wr_drv_cb_t.dqs_c <= 'z;

    // Write Recovery

    repeat(`TWR)

      @(vif.ddr5_drv_cb_t);

  endtask

  // Write AP

  task write_ap(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    ca1 = {3'b000, seq.bg, seq.ba, seq.bl, 5'b01101};

    ca2 = {5'b00000, seq.col[10:3], 1'b0};

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

  endtask

  // Read

  task read(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    bit cmd_bl;

    if ((seq.bl == BC8_OTF) || (seq.bl == BL32_OTF))

      cmd_bl = 1'b1;

    else

      cmd_bl = 1'b0;

    ca1 = {3'b000, seq.bg, seq.ba, cmd_bl, 5'b11101};

    ca2 = {5'b00000, seq.col[10:2]};

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

    release_ca();

    `uvm_info("DDR5_DRV", $sformatf("READ : CA1=%014b CA2=%014b BG=%0d BA=%0d COL=%0d BL=%0d RL=%0d", ca1, ca2, seq.bg, seq.ba, seq.col, seq.bl, seq.rl), UVM_LOW)

    repeat(seq.rl)

      @(vif.ddr5_drv_cb_t);

  endtask

  // Read AP

  task read_ap(ddr5_seq_item seq);

    bit [13:0] ca1, ca2;

    ca1 = {3'b000, seq.bg, seq.ba, seq.bl, 5'b11101};

    ca2 = {seq.col[10], 2'b00, 1'b1, seq.col[9:0]};

    drive_cmd(1'b0, ca1);

    drive_cmd(1'b1, ca2);

  endtask

  // Precharge

  task precharge(ddr5_seq_item seq);

    bit [13:0] ca;

    ca = {3'b000, seq.bg, seq.ba, 1'b0, 5'b11011};

    drive_cmd(1'b0, ca);

    drive_cmd(1'b1, 'x);

  endtask

  // Precharge Same Bank

  task precharge_sb(ddr5_seq_item seq);

    bit [13:0] ca;

    ca = {6'b000000, seq.ba, 1'b0, 5'b01011};

    drive_cmd(1'b0, ca);

    drive_cmd(1'b1, 'x);

  endtask

  // Precharge All

  task precharge_all();

    bit [13:0] ca;

    ca = {8'b00000000, 1'b1, 5'b01011};

    drive_cmd(1'b0, ca);

    drive_cmd(1'b1, 'x);

  endtask

  // Power Down Entry

  task powerdown_entry();

    bit [13:0] ca;

    ca = {3'b000, 1'b0, 1'b1, 5'b10111};

    drive_cmd(1'b0, ca);

    drive_cmd(1'b1, 'x);

  endtask

  // Power Down Exit

  task powerdown_exit();

    bit [13:0] ca;

    ca = {9'b000000000, 5'b11111};

    drive_cmd(1'b0, ca);

    drive_cmd(1'b1, 'x);

  endtask

  // Drive Transaction

  task drive_tx(ddr5_seq_item seq);

    vif.cmd <= seq.cmd;

    `uvm_info("DRV", $sformatf("Received cmd=%0d", seq.cmd), UVM_LOW)

    case (seq.cmd)

ACTIVATE: begin

  if(seq.faw_test) begin

    faw_count++;

    if(faw_count == 1) begin
      activate(seq);
    end
    else if(faw_count < 5) begin
      repeat(`FAW_RRD_GAP)
        @(vif.ddr5_drv_cb_t);
      activate(seq);
    end
    else begin
      repeat(`FAW_VIOLATION_GAP)
        @(vif.ddr5_drv_cb_t);
      activate(seq);
    end
   if ((seq.faw_test == 2 && faw_count == 4) ||
        (seq.faw_test == 1 && faw_count == 5)) begin
      repeat (`TRCD)
        @(vif.ddr5_drv_cb_t);
      faw_count = 0;
    end 
  end
  else begin

    activate(seq);

    repeat(`TRCD)
      @(vif.ddr5_drv_cb_t);

  end

end

      WRITE: begin

        write(seq);

        repeat(`TWR)

          @(vif.ddr5_drv_cb_t);

      end

      READ: begin

        read(seq);

        repeat(`TRTP)

          @(vif.ddr5_drv_cb_t);

      end

      MRW: begin

        bit [7:0] mr_opcode;

        if (seq.mra == 8'd8) begin

          mr_opcode = {seq.wr_postamble, seq.rd_postamble, 1'b0, seq.wr_preamble, seq.rd_preamble};

          mrw(seq.mra, mr_opcode);

        end

        else begin

          mrw(seq.mra, seq.mr_opcode);

        end

      end

      default: begin

        `uvm_error("DDR5_DRV", $sformatf("Unknown command %0d", seq.cmd))

      end

    endcase

  endtask

endclass
 
 

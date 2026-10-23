typedef enum {NOP,DES,ACTIVATE,WRITE,WRITE_AP,READ,READ_AP,PRECHARGE,PRECHARGE_ALL,PRECHARGE_SB,MRW,MRR,PD_E,PD_X} rand_cmd;

// mr0

typedef enum bit [1:0] {
 
    BL16     = 2'b00,

    BC8_OTF  = 2'b01,

    BL32     = 2'b10,

    BL32_OTF = 2'b11
 
} burst_length_e;
 
typedef enum bit [4:0]{

	RL22  = 5'b00000,

        RL24  = 5'b00001,

        RL26  = 5'b00010,

        RL28  = 5'b00011,

        RL30  = 5'b00100,

        RL32  = 5'b00101,

        RL34  = 5'b00110,

        RL36  = 5'b00111,

        RL40  = 5'b01001,

        RL44  = 5'b01011,

        RL48  = 5'b01101

       	} read_latency;

//mr5
 
 
typedef enum bit {

  DM_ENABLE  = 1'b1,

  DM_DISABLE = 1'b0
 
	}dm_en;
 
//mr6

typedef enum bit[3:0]{

	WR48 = 4'b0000,

    	WR54 = 4'b0001,

    	WR60 = 4'b0010, 

     	WR66 = 4'b0011,  

      	WR72 = 4'b0100,  

      	WR78 = 4'b0101, 

     	WR84 = 4'b0110,  

      	WR90 = 4'b0111,  

      	WR96 = 4'b1000
 
	} write_recovery;
 
typedef enum bit [3:0]{

	TRTP12 = 4'b0000,

        TRTP14 = 4'b0001,

	TRTP15 = 4'b0010,

	TRTP17 = 4'b0011,

	TRTP18 = 4'b0100,

	TRTP20 = 4'b0101,

	TRTP21 = 4'b0110,

	TRTP23 = 4'b0111,

	TRTP24 = 4'b1000
 
} mr6_trp;

// mr13

typedef enum bit [3:0]{

        SPEED_3200 = 4'b0000,

        SPEED_4800 = 4'b0101,

        SPEED_5600 = 4'b0111,

        SPEED_6400 = 4'b1000

	} mr_13_speed;

//mr50

typedef enum bit{

   CRC_ENABLE =1'b1,

   CRC_DISABLE=1'b0

	} crc_enable;

//mr8

typedef enum bit [2:0]{

	RD_PRE_1TCK        = 3'b000,

        RD_PRE_2TCK        = 3'b001,

        RD_PRE_2TCK_DDR4   = 3'b010,

        RD_PRE_3TCK        = 3'b011,

        RD_PRE_4TCK        = 3'b100

	}read_preamble;

typedef enum bit [1:0]{

        WR_PRE_2TCK   = 2'b01,

        WR_PRE_3TCK   = 2'b10,

        WR_PRE_4TCK   = 2'b11
 
	}write_preamble;

typedef enum bit   {

	RD_PSTBLE_0_5TCK = 1'b0,

	RD_PSTBLE_1_5TCK = 1'b1

	} read_postamble;
 
typedef enum bit   {

	WR_PSTBLE_0_5TCK = 1'b0,

	WR_PSTBLE_1_5TCK = 1'b1

	} write_postamble;
 
class ddr5_seq_item extends uvm_sequence_item;

  `uvm_object_utils(ddr5_seq_item)

  rand    burst_length_e bl;

  rand    read_latency rl;

  rand    dm_en dm_cfg;

  rand    write_recovery wr_recovery;

  rand    mr6_trp trp_cfg;

  rand    mr_13_speed dll_time;

  rand    crc_enable crc_en;

  rand    read_preamble rd_preamble;

  rand    write_preamble wr_preamble;

  rand    read_postamble rd_postamble;

  rand    write_postamble wr_postamble;
 
  rand bit cs_n;  //chip select

  rand bit reset_n;

  rand rand_cmd cmd;

  rand bit [`BG_WIDTH-1:0]   bg;

  rand bit [`BA_WIDTH-1:0]   ba;

  rand bit [`COL_WIDTH-1:0]  col;

  rand bit [`ROW_WIDTH-1:0]  row;

  rand bit [`DATA_WIDTH-1:0] dq;

  rand bit dqs_c;

  rand bit dqs_t;

  rand bit dm;

  rand bit ap_n; //Auto precharge pin

  rand bit [7:0]mra;

  rand bit [7:0]mr_opcode;

logic dqs_t_preamble [0:7];

logic dqs_c_preamble [0:7];
 
bit seamless_write = 1'b0;

int observed_write_tccd = 0;
 
bit data_capture_done = 1'b1; 
//tFAW variables

int faw_test;

realtime command_time;
 
logic dqs_t_burst [0:15];

logic dqs_c_burst [0:15];
 
 
//DQSL and DQSU for x16 

logic dqsl_t_preamble [0:7];

logic dqsl_c_preamble [0:7];

logic dqsu_t_preamble [0:7];

logic dqsu_c_preamble [0:7];
 
 
logic dqsl_t_burst [0:15];

logic dqsl_c_burst [0:15];

logic dqsu_t_burst [0:15];

logic dqsu_c_burst [0:15];
 
rand logic [`DATA_WIDTH-1:0] dq_burst[16];
 
//data mask for x16

rand bit dml_burst[16];

rand bit dmu_burst[16];
 
//Data mask for x8

rand bit dm_burst[16];

   constraint c1 {soft reset_n == 1'b1;}
  // constraint c1 {soft foreach (dm_burst[i])
 //dm_burst[i] == 1'b1;}
 
  function new(string name ="ddr5_seq_item");

    super.new(name);

  endfunction

  function void do_print(uvm_printer printer);

    printer.print_field("cmd",this.cmd,UVM_DEC);

    printer.print_field("bg",this.bg,UVM_DEC);

    printer.print_field("ba",this.ba,UVM_DEC);

    printer.print_field("row",this.row,UVM_DEC);

    printer.print_field("col",this.col,UVM_DEC);

    printer.print_field("dq",this.dq,UVM_DEC);

  endfunction

endclass
 
 
 

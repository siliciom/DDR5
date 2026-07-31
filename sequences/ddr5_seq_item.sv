typedef enum {IDLE,MRS,NOP,DES,ACTIVATE,WRITE,READ,PRECHARGE,BSTC,MRW,MRR,PD_ENTRY,PD_EXIT}rand_cmd;
class ddr5_seq_item extends uvm_sequence_item;
  `uvm_object_utils(ddr5_seq_item)
  
  
  rand bit cs_n;  //chip select
  rand bit reset_n;
  rand rand_cmd cmd;
  rand bit [2:0] bg;  //bank group 
  rand bit [1:0] ba;  // banks
  rand bit [10:0] col; // coulmn
  rand bit [18:0] row; // row
  rand bit [63:0] dq; //data
  rand bit dqs_c;
  rand bit dqs_t;
  rand bit dm;
  
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
    

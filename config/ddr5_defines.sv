//==============================================================================
// Component Name : DDR_defines
// Description    : Configures the core memory data, column, and address widths 
//                  based on the targeted memory chip layout macro (`ifdef).
//==============================================================================
`ifdef DDR_X4

  `define DATA_WIDTH  4

  `define BG_WIDTH    3      // BG0-BG2 = 8 BG
  `define BA_WIDTH    2      // BA0-BA1 = 4 banks per BG
  `define COL_WIDTH   11     // C0-C10
  `define ROW_WIDTH  18     // R0-R17


`elsif DDR_X8

  `define DATA_WIDTH  8

  `define BG_WIDTH    3      // BG0-BG2 = 8 BG
  `define BA_WIDTH    2      // BA0-BA1 = 4 banks per BG
  `define COL_WIDTH   10     // C0-C9
  `define ROW_WIDTH  18     // R0-R17


`else

  // Default = DDR_X16
  `define DATA_WIDTH  16

  `define BG_WIDTH    2      // BG0-BG1 = 4 BG
  `define BA_WIDTH    2      // BA0-BA1 = 4 banks per BG
  `define COL_WIDTH   10     // C0-C9
  `define ROW_WIDTH  18     // R0-R17

`endif

// DDR5 Speed Configuration

`ifdef DDR5_6400
  `define CK_FREQ_MHZ 3200.0

`elsif DDR5_4800
  `define CK_FREQ_MHZ 2400.0

`elsif DDR5_5600
  `define CK_FREQ_MHZ 2800.0

 `else 
  `define CK_FREQ_MHZ 1600.0
 
`endif

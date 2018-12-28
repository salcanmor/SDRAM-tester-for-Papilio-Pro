`timescale 1ns / 1ps

module sdram_controller2( sdram_cke, sdram_clk, sdram_cs_n, sdram_we_n, sdram_ras_n, sdram_cas_n, sdram_addr, sdram_ba, sdram_dqmh_n, sdram_dqml_n, sdram_dq, sys_clk, sys_reset, sys_addr, sys_write_rq, sys_read_rq, sys_rfsh_rq, sys_data_in, sys_data_out, sys_busy);

  // sdram interface
  output wire sdram_cke;			//	 Clock enable
  output reg sdram_clk;             // Clock input to SDRAM. All input signals are referenced to positive edge of CLK

  //	BEGIN: Command signals that define current operation

  output wire sdram_cs_n;		    //	Chip select
  output wire sdram_we_n;			//	Write enable
  output wire sdram_ras_n;			//	Row address strobe
  output wire sdram_cas_n;	    	//	Column address strobe

  //	END: Command signals that define current operation

  output wire [11:0] sdram_addr;    // pag.14. row=[11:0], col=[7:0]. A10=1 significa precharge all.
  output wire [1:0] sdram_ba;       // banco al que se accede

  output wire sdram_dqmh_n;         // mascara para byte alto o bajo
  output wire sdram_dqml_n;         // durante operaciones de escritura

  inout tri [15:0] sdram_dq;

  // host interface

  input wire sys_clk;                // este reloj debe ser el doble del reloj de la SDRAM
  input wire sys_reset;              // normalmente conectado a la versión negada del pin "locked" del PLL/MMCM

  input wire [21:0] sys_addr;        // address to SDRAM (up to 4M addresses). 22 bits = 12 row addr + 2 BA + 8 column addr

  input wire sys_write_rq;           //
  input wire sys_read_rq;            // Operation request signal (active high)
  input wire sys_rfsh_rq;            //


  // input wire [22:0] sys_cmd;       
  input wire [15:0] sys_data_in;     // Data to be written to SDRAM
  input wire [15:0] sys_data_out;    // Data to be read from SDRAM

  output reg sys_busy;               // Active high during operation processing


  parameter
  FREQCLKSDRAM = 64,    // frecuencia en MHz a la que irá la SDRAM
  CL           = 3'd2;  // 3'd2 si es -7E, 3'd3 si es -75

  localparam   // comandos a la SDRAM. RAS,CAS,WE (pag. 29)
  NO_OP = 3'b111,  // no operation
  ACTIV = 3'b011,  // select bank and activate row. addr=fila, ba=banco
  READ  = 3'b101,  // select bank and column, and start READ burst. addr[8:0]=columna. ba=banco. A10=1 para precharge después de read
  WRIT  = 3'b100,  // select bank and column, and start WRITE burst. Mismas cosas que en READ. El dato debe estar ya presente en DQ
  BTER  = 3'b110,  // burst terminate
  PREC  = 3'b010,  // precarga. A10=1, precarga todos los bancos. A10=0, BA determina qué banco se precarga.
  ASRF  = 3'b001,  // autorefresh si CKE=1, self refresh si CKE=0
  LMRG  = 3'b000   // load mode register. Modo en addr[11:0]
  ;

  reg [2:0] comando;        //  señal para los comandos
  reg cke;                  //  clock enable
  reg [1:0] ba;             //  bank address input
  reg dqmh_n, dqml_n;
  reg [11:0] saddr;
  assign sdram_addr = saddr;
  assign sdram_ras_n = comando[2];
  assign sdram_cas_n = comando[1];
  assign sdram_we_n  = comando[0];
  assign sdram_cke = cke;
  assign sdram_ba = ba;
  assign sdram_dqmh_n = dqmh_n;
  assign sdram_dqml_n = dqml_n;
  assign sdram_cs_n = 1'b0;    // siempre activa!

  localparam
    WAIT100US  = 100*FREQCLKSDRAM,
    TRP        = (20*FREQCLKSDRAM/1000)+1,      // TRP = row precharge time, time required to precharge a row for another access.
    TRFC       = (66*FREQCLKSDRAM/1000)+1,      // TRFC = Duration of refresh command
    TRCD       = (20*FREQCLKSDRAM/1000)+1       // TRCD = ras_n to cas_n delay time, the minimal delay between the assertion of ras_n and the assertion of cas_n. It represents the time to retrieve data from a row.
    ;



endmodule

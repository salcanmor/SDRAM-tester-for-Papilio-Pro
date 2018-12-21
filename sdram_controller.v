`timescale 1ns / 1ps

module sdram_controller(
  input wire clk,                // este reloj debe ser el doble del reloj de la SDRAM
  ///input wire clken,              // enable para el reloj, para poder ir más lento si hiciera falta
  input wire reset,              // normalmente conectado a la versión negada del pin "locked" del PLL/MMCM
 
 // host interface
 /// input wire [23:0] addr,        // address to SDRAM (up to 16M addresses)
  input wire [21:0] addr,        // address to SDRAM (up to 4M addresses)
  input wire write_rq,           //
  input wire read_rq,            // Operation request signal (active high)
  input wire rfsh_rq,            //
  input wire [15:0] din,         // Data to be written to SDRAM
  output reg [15:0] dout,        // Data to be read from SDRAM
  output reg busy,               // Active high during operation processing
 
 // sdram interface
  output reg sdram_clk,          // señales validas en flanco de suida de CK
  output wire sdram_cke,
  output wire sdram_dqmh_n,      // mascara para byte alto o bajo
  output wire sdram_dqml_n,      // durante operaciones de escritura
  ///output wire [12:0] sdram_addr, // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
  output wire [11:0] sdram_addr, // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
  output wire [1:0] sdram_ba,    // banco al que se accede
  output wire sdram_cs_n,
  output wire sdram_we_n,
  output wire sdram_ras_n,
  output wire sdram_cas_n,
  inout tri [15:0] sdram_dq
  );
  
    parameter
    FREQCLKSDRAM = 64,    // frecuencia en MHz a la que irá la SDRAM
    CL           = 3'd2;  // 3'd2 si es -7E, 3'd3 si es -75


  localparam   // comandos a la SDRAM. RAS,CAS,WE (pag. 32)
    NO_OP = 3'b111,  // no operation
    ACTIV = 3'b011,  // select bank and activate row. addr=fila, ba=banco
    READ  = 3'b101,  // select bank and column, and start READ burst. addr[8:0]=columna. ba=banco. A10=1 para precharge después de read
    WRIT  = 3'b100,  // select bank and column, and start WRITE burst. Mismas cosas que en READ. El dato debe estar ya presente en DQ
    BTER  = 3'b110,  // burst terminate
    PREC  = 3'b010,  // precarga. A10=1, precarga todos los bancos. A10=0, BA determina qué banco se precarga.
    ASRF  = 3'b001,  // autorefresh si CKE=1, self refresh si CKE=0
    LMRG  = 3'b000  // load mode register. Modo en addr[11:0]
    ;




endmodule

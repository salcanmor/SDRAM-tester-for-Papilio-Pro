`timescale 1ns / 1ps

module sdram_controller2( sdram_cke, sdram_clk, sdram_cs_n, sdram_we_n, sdram_ras_n, sdram_cas_n, sdram_addr, sdram_ba, sdram_dqmh_n, sdram_dqml_n, sdram_dq, sys_clk, sys_reset, sys_addr, sys_write_rq, sys_read_rq, sys_rfsh_rq, sys_data_in, sys_data_out, sys_busy);

  input wire sys_clk;                // este reloj debe ser el doble del reloj de la SDRAM
  input wire sys_reset;              // normalmente conectado a la versión negada del pin "locked" del PLL/MMCM


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
    
    //Estados de mi máquina de estados
    
      localparam
      RESET             = 5'd0,    // CKE a 0 durante este periodo. Esperar 100us (MAXCONT100)
      INIT_PRECHARGEALL = 5'd1,    // tras los 100us, se hace un precharge all. Hay que esperar tRP = 20ns
      INIT_AUTOREFRESH1 = 5'd2,    // tras esperar, se hace un autorefresh y se esperan tRFC = 66 ns
      INIT_AUTOREFRESH2 = 5'd3,    // tras esperar, se hace otro autorefresh y se esperan tRFC = 66 ns
      INIT_LOAD_MODE    = 5'd4,    // cargar el registro de modo y esperar tMRD = 2 clks
      IDLE              = 5'd5,    // espera a por un comando
      ACTIVE_ROW_READ   = 5'd6,    // activa una fila
      ISSUE_READ        = 5'd7,    // activa una columna y manda leer
      GET_DATA          = 5'd8,    // recoge el dato leido
      ACTIVE_ROW_WRITE  = 5'd9,
      ISSUE_WRITE       = 5'd10,
      DO_AUTOREFRESH    = 5'd11,
      WAIT_STATES       = 5'd31;   // subFSM para esperar N estados de reloj
                                   // El estado WAIT_STATES es una subrutina en la FSM, ya que cuando se termina ese estado, se vuelve al siguiente estado a aquel que lo llamó, por lo que también se carga otro registro que contiene el estado al que se retorna (como una pila con profundidad 1).


  localparam
    modo_operacion_sdram = {6'b000_1_00,CL,4'b0_000};   // pag. 43. El valor de CL depende de si es -75 o -7E
//13 bits:
// 3 bits. Reserved: Los 3 primeros bits estan reservados para futuras compatibilidades y se dejan a 0
// 1 bit. WB: Write Burst Mode. 0 para ráfagas y 1 para no tener ráfagas.
// 2 bits. Op Mode. 00 para modo estandar.
// 3 bits. CAS Lantecy. Depende del chip q tengamos -75 o -7E
// 1 bit. BT: Burst Type. 0 Secuencial y 1 intercalado
// 3 bits. Burst Length. Tamano de la rafaga.

// Mode register bits M[2:0] specify the BL; M3 specifies the type of burst; M[6:4] specify the CL; M7 and M8 specify the operating mode; M9 specifies the write burst mode; and M10-Mn should be set to zero to ensure compatibility with future revisions. Mn + 1 and Mn + 2 should be set to zero to select the mode register.

  reg load_wsreg;                       //  No tengo ni idea de para q vale esta señal, siempre esta a 1
  reg [13:0] cont_wstates = 14'd0;      //  Depende de load_wsreg. Es quien cuenta el número de ciclos de reloj de espera, que es diferente para cada caso
  reg [13:0] wait_states;               //  Depende de cont_wstates. Indica la cuenta máxima del contador, es decir, todos los ciclos de reloj que hay que esperar


  reg [4:0] state = RESET;              //  Creamos la variable para los estados de la FSM y la inicializamos con RESET (estado inicial)
  reg [4:0] next_state;                 //  Variable para el siguiente estado de la FSM
  reg load_rtstate;                     //  Variable para cargar la subrutina WAIT_STATES
  reg [4:0] reg_return_state = RESET;   //  Con esta variable indicamos a qué estado tenemos que volver al salir de la subrutina
  reg [4:0] return_state;               //  Con esta variable indicamos a qué estado tenemos que volver al salir de la subrutina

  reg load_dout;                        //  Variable para activar la salida del dato leído de la SRAM.

/// MÁQUINA DE ESTADOS
  always @* begin                           // bloque combinacional que en función del estado actual y de las entradas, calcula las salidas y el nuevo estado.
    cke = 1'b1;  // valores por defecto
    ba = 2'b00;										//	** Si en un case, dentro de un always combinacional, no especifico el valor de una señal, ésta toma el valor por defecto que hubiera puesto al principio. **
    dqmh_n = 1'b0;
    dqml_n = 1'b0;
    load_wsreg = 1'b0;
    wait_states = 14'd0;
    comando = NO_OP;
    load_rtstate = 1'b0;
    return_state = RESET;
    next_state = RESET;
    sys_busy = 1'b1;
    saddr = 13'h0000;
    load_dout = 1'b0;
    case (state)
      RESET: 
        begin
          cke = 1'b0;
          wait_states = WAIT100US;
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = INIT_PRECHARGEALL;
        end
      INIT_PRECHARGEALL:
        begin
          comando = PREC;       // tras este comando hay que esperar tRP = 20 ns (2 CLK @64 MHz)
          wait_states = TRP-1;  
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = INIT_AUTOREFRESH1;
        end
      INIT_AUTOREFRESH1:
        begin
          comando = ASRF;       // tras este comando hay que esperar tRFC = 66 ns (5 CLKs @64 MHz)
          wait_states = TRFC-1;
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = INIT_AUTOREFRESH2;
        end          
      INIT_AUTOREFRESH2:
        begin
          comando = ASRF;       // tras este comando hay que esperar tRFC = 66 ns (5 CLKs @64 MHz)
          wait_states = TRFC-1;  
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = INIT_LOAD_MODE;
        end    
      INIT_LOAD_MODE:
        begin
          comando = LMRG;       // tras este comando hay que esperar 2 CLKs
          saddr = modo_operacion_sdram;
          wait_states = 14'd1;  // 1 CLKs
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = IDLE;
        end        
      IDLE:
        begin
          sys_busy  = 1'b0;
          casex ({sys_rfsh_rq, sys_read_rq, sys_write_rq})
            3'b1xx:  next_state = DO_AUTOREFRESH;
            3'b01x:  next_state = ACTIVE_ROW_READ; 
            3'b001:  next_state = ACTIVE_ROW_WRITE;
            default: next_state = IDLE;
          endcase
        end
      ACTIVE_ROW_READ:
        begin
          comando = ACTIV;      // tras este comando, hay que esperar tRCD (20 ns, o sea 2 CLK @64 MHz)
          saddr = sys_addr[23:11];  // fila que queremos abrir (parte más alta de la dirección)
          ba = sys_addr[1:0];       // el banco lo establecen los dos bits más bajos de la dirección
          wait_states = TRCD-1; // 1 CLKs para esperar ACTIV
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = ISSUE_READ;
        end
      ISSUE_READ:
        begin
          comando = READ;
          saddr = {4'b0010, sys_addr[10:2]};   // columna. auto-precharge (20ns) al final del read
          ba = sys_addr[1:0];
          wait_states = CL-1;  // 2 o 3 ws
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = GET_DATA;
        end
      GET_DATA:
        begin
          load_dout = 1'b1;
          wait_states = TRP-1;  // 1 CLKs para esperar el autoprecharge
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = IDLE;
        end
      ACTIVE_ROW_WRITE:
        begin
          comando = ACTIV;      // tras este comando, hay que esperar tRCD (20 ns, o sea 2 CLK @64 MHz)
          saddr = sys_addr[23:11];  // fila que queremos abrir (parte más alta de la dirección)
          ba = sys_addr[1:0];       // el banco lo establecen los dos bits más bajos de la dirección
          wait_states = TRCD-1; // 1 CLKs para esperar ACTIV
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = ISSUE_WRITE;
        end
      ISSUE_WRITE:
        begin
          comando = WRIT;
          saddr = {4'b0010, sys_addr[10:2]};   // columna. auto-precharge (20ns) al final del read
          ba = sys_addr[1:0];
          wait_states = TRP;   // después de WRITE, esperar (NOP+autoprecharge)
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = IDLE;
        end
      DO_AUTOREFRESH:
        begin
          comando = ASRF;       // tras este comando hay que esperar 66 ns (5 CLKs @64 MHz)
          wait_states = TRFC-1;
          load_wsreg = 1'b1;
          next_state = WAIT_STATES;
          load_rtstate = 1'b1;
          return_state = IDLE;
        end    
          
      WAIT_STATES:
        begin
          comando = NO_OP;
          if (cont_wstates == 14'd1)
            next_state = reg_return_state;
          else
            next_state = WAIT_STATES;
        end
    endcase
  end

  initial sdram_clk = 1'b0;

  always @(posedge clk) begin
    if (clken == 1'b1) begin
      sdram_clk <= ~sdram_clk;
      if (reset == 1'b1) begin
        state <= RESET;
      end
      else begin
        if (sdram_clk == 1'b1) begin
          state <= next_state;
          if (load_rtstate == 1'b1)
            reg_return_state <= return_state;
        end
      end
    end
  end


  always @(posedge clk) begin
    if (clken == 1'b1) begin
      if (sdram_clk == 1'b1) begin
        if (load_wsreg == 1'b1)
          cont_wstates <= wait_states;
        else if (cont_wstates != 14'd0)
          cont_wstates <= cont_wstates + 14'h3FFF;  // sumar -1
        else
          cont_wstates <= 14'd0;
      end
    end
  end


  always @(posedge clk) begin
    if (clken == 1'b1) begin
      if (load_dout == 1'b1)
        dout <= sdram_dq;
    end
  end

  assign sdram_dq = (state == ISSUE_WRITE)? din : 16'hZZZZ;

endmodule

`default_nettype wire

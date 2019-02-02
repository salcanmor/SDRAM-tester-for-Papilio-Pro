`timescale 1ns / 1ps

//  Las señales que comienzan con sys_ son las que conectan con la lógica que usuario.
//  Las señales que comienzan con sdram_ son las que conectan con chip SDRAM.

//  MODIFICACIONES ANTES DE RELEASE:
//  1-  PONER UN BLOQUE INITIAL COMO RESET, COMO HICE EN LA SRAM
//  2-  QUITAR LA VARIABLE save_data Y EN SU LUGAR PONER EL DATO ENTRANTE


module sdram_controller2(
  sys_clk, sys_addr, sys_data_to_sdram, sys_data_from_sdram, sys_data_from_sdram_valid, sys_write_done, sys_write_rq, sys_read_rq,
  sdram_clk, sdram_cke, sdram_addr, sdram_dq, sdram_ba, sdram_dqmh_n, sdram_dqml_n, sdram_cs_n, sdram_we_n, sdram_ras_n, sdram_cas_n, state_
);

  // HOST interface 
  input wire sys_clk;                     // este reloj debe ser el doble del reloj de la SDRAM
  input wire [21:0] sys_addr;             // address to SDRAM (up to 4M addresses). 22 bits = [ 12 row addr + 8 column addr + 2 BA ]
  //  [21:10] 12 bits row address, [9:2] 8 bits col address, [1:0] 2 bits bank  <--- poner de esta forma mas adelante
  //  [21:14] 8 bits col address, [13:12] 2 bits bank, [11:0] 12 bits row address

  input wire [15:0] sys_data_to_sdram;    // Data to be written to SDRAM
  input wire sys_write_rq;                //  Operation (WRITE) request signal (active high) 
  input wire sys_read_rq;                 //  Operation (READ) request signal (active high)

  output [15:0] sys_data_from_sdram;  // Data to be read from SDRAM
  output wire sys_data_from_sdram_valid; 
  output wire sys_write_done; 


  //  SDRAM interface
  output wire sdram_clk;                  // Clock input to SDRAM. All input signals are referenced to positive edge of CLK
  output wire sdram_cke;   //  Clock enable
  output wire [11:0] sdram_addr;          // pag.14. row=[11:0], col=[7:0]. A10=1 significa precharge all.
  output wire [1:0] sdram_ba;
  output sdram_dqmh_n;               //  mascara para byte alto durante operaciones de escritura
  output sdram_dqml_n;               //  mascara para byte bajo durante operaciones de escritura
  output wire sdram_cs_n;                 //  Chip select
  output wire sdram_we_n;                 //  Write enable
  output wire sdram_ras_n;                //  Row address strobe
  output wire sdram_cas_n;                //  Column address strobe
  output [3:0] state_;

  inout tri [15:0] sdram_dq;


  // comandos a la SDRAM. RAS,CAS,WE (pag. 29)
  localparam
  CMD_INHIBIT = 4'b1000,  //  COMMAND INHIBIT (NOP)
  CMD_NO_OP   = 4'b0111,  /// no operation
  CMD_ACTIVE   = 4'b0011,  /// select bank and activate row. addr=fila, ba=banco
  CMD_READ    = 4'b0101,  /// select bank and column, and start READ burst. addr[8:0]=columna. ba=banco. A10=1 para precharge después de read
  CMD_WRITE    = 4'b0100,  /// select bank and column, and start WRITE burst. Mismas cosas que en READ. El dato debe estar ya presente en DQ
  CMD_TERMINATE    = 4'b0110,  // burst terminate
  CMD_PRECHARGE    = 4'b0010,  /// precarga. A10=1, precarga todos los bancos. A10=0, BA determina qué banco se precarga.
  CMD_REFRESH    = 4'b0001,  /// autorefresh si CKE=1, self refresh si CKE=0
  CMD_LOAD_MODE_REG    = 4'b0000   /// load mode register. Modo en addr[11:0]
  ;

  reg [3:0] cmd = CMD_NO_OP, next_cmd = CMD_NO_OP;

  assign sdram_cs_n = cmd[3];
  assign sdram_ras_n = cmd[2];
  assign sdram_cas_n = cmd[1];
  assign sdram_we_n = cmd[0];


  reg [1:0] dqm = 2'b00;
  assign sdram_dqmh_n = dqm[0];
  assign sdram_dqml_n = dqm[1];

  //Estados de la FSM
  localparam INIT = 0,    //0000
  WAIT = 1,    //0001
  PRECHARGE_INIT = 2,//0010
  REFRESH_INIT_1 = 3,//0011
  REFRESH_INIT_2 = 4,//0100
  LOAD_MODE_REG = 5, //0101
  IDLE = 6,    //0110
  REFRESH = 7,   //0111
  ACTIVATE = 8,  //1000
  READ = 9,    //1001
  READ_RES = 10,   //1010 
  WRITE = 11,    //1011
  PRECHARGE = 12;  //1100

  reg [3:0] state = INIT, next_state = INIT;

  reg data_dir = 0;
  reg [15:0] save_data = 0;
  assign sdram_dq = data_dir ? save_data : 16'hZZZZ; 

  //refresh controller
  //for 133mhz refresh every 1039 clk. sE COGEN 11 BITS PORQUE PARA ALMACENAR 1039 HACEN FALTA 11, CON 10 NO LLEGA.
  //FOR 100MHZ refresh every 
  reg [10:0] refresh_ctr = 0;       // Contador para refresco, para esperar justamente el tiempo que se necesita esperar
  reg refresh_flag = 0;

  reg [13:0] delay_ctr = 0;         // Contador para añadir retraso, para esperar justamente el tiempo que se necesita esperar


  reg [13:0] addr = 0, save_addr = 0;
  reg row_opend = 0;


  assign sdram_addr = addr[11:0];
  assign sdram_ba = addr[13:12];


  reg sys_data_from_sdram_valid_reg = 0;
  assign sys_data_from_sdram_valid = sys_data_from_sdram_valid_reg;

  reg sys_write_done_reg = 0;
  assign sys_write_done = sys_write_done_reg;

  reg cke = 0;
  assign sdram_cke = cke;

  reg [15:0] data = 0;
  assign sys_data_from_sdram = data;

 // assign sdram_clk = sys_clk;

  assign state_ = state;
 
    wire sdram_clk_oddr2;
 
  
     ODDR2 #(
      .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
   ) ODDR2_inst (
      .Q(sdram_clk_ddr),   // 1-bit DDR output data
      .C0(sys_clk),   // 1-bit clock input
      .C1(~sys_clk),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D0(1'b0), // 1-bit data input (associated with C0)
      .D1(1'b1), // 1-bit data input (associated with C1)
      .R(1'b0),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
   );




   IODELAY2 #(
        .IDELAY_VALUE(0),
        .IDELAY_MODE("NORMAL"),
        .ODELAY_VALUE(100), // value of 100 seems to work at 100MHz
        .IDELAY_TYPE("FIXED"),
        .DELAY_SRC("ODATAIN"),
        .DATA_RATE("SDR")
    ) IODELAY_inst (
        .IDATAIN(1'b0),
        .T(1'b0),
        .ODATAIN(sdram_clk_ddr),
        .CAL(1'b0),
        .IOCLK0(1'b0),
        .IOCLK1(1'b0),
        .CLK(1'b0),
        .INC(1'b0),
        .CE(1'b0),
        .RST(1'b0),
        .BUSY(),
        .DATAOUT(),
        .DATAOUT2(),
        .TOUT(),
        .DOUT(sdram_clk)
    );



  
  //Comienzo de la state machine

  always @ (posedge sys_clk) begin

    //init refresh count refresh every 7.81us <= ese valor es tRFC
    refresh_ctr = refresh_ctr + 1'b1;
    //  if (refresh_ctr > 11'd1024) begin //due 11'd1039: early than request for 
    if (refresh_ctr > 11'd1530) begin //due 11'd1039: early than request for 


      // El periodo de 133 MHz es 7,518797 ns. 
      //    7,813 us = 7813 ns
      //    Por tanto 7813 / 7,518797 = 1039 ciclos de reloj. Por tanto, hay q emitir el refresh cada 1039 como máximo. Sino perdermos el dato.
      // Sin embargo, lo vamos a lanzar 15 ciclos antes (1024), por seguridad.


      // El periodo de 100 MHz es 10 ns. 
      //    15.625 us = 15625 ns
      //    Por tanto 15625 / 10 = 1.562,5 ciclos de reloj. Por tanto, hay q emitir el refresh cada 1.562,5 como máximo. Sino perdermos el dato.
      // Sin embargo, lo vamos a lanzar 32 ciclos antes (1530), por seguridad.

      //reading and writing also cause slow in performance
      refresh_ctr = 11'd0;
      refresh_flag = 1'b1;
    end

    case(state)

      INIT: begin
        // set all the init values
        // power on clk on CKe = 1 and nop for 100us (clk133 Mhz or 7.5us) or
        // 13333.333333333334  delay_ctr = 13334 clock

        // Hay q quedarse en NOP al menos 100 us. 100 us = 100.000 ns
        // Si 1 ciclo de reloj son 7.5 ns, 100.000 ns corresponden a (100.000/7.5)  = 13.333,33333333333 ciclos de reloj. Redondeando serian 13334 ciclos de reloj.  

        //  Para 100 MHz
        // Hay q quedarse en NOP al menos 100 us. 100 us = 100.000 ns
        //  Si 1 ciclo de reloj son 10 ns, 100.000 ns corresponden a (100.000/10) = 10.000 ciclos de reloj

        dqm = 0;
        cke = 1;
        cmd = CMD_NO_OP;
        state = WAIT;
        delay_ctr = 10100;          // Le meto 100 ciclos más por seguridad.
        next_state = PRECHARGE_INIT; 
      end

      WAIT: begin
        cmd = next_cmd;
        if (delay_ctr > 0) begin
          delay_ctr = delay_ctr - 1'b1;
        end else
          state = next_state;
      end

      PRECHARGE_INIT: begin
        cmd = CMD_PRECHARGE;
        addr[10] = 1;
        delay_ctr = 3 - 2;
       // delay_ctr = 10100;
        state = WAIT;
        next_state = REFRESH_INIT_1;
        next_cmd = CMD_NO_OP;
      end


      REFRESH_INIT_1: begin
        cmd = CMD_REFRESH;
        next_cmd = CMD_NO_OP;
        delay_ctr = 9-2;
        state = WAIT;
        next_state = REFRESH_INIT_2;
      end


      REFRESH_INIT_2:begin
        cmd = CMD_REFRESH;
        next_cmd = CMD_NO_OP;
        delay_ctr = 9-2;
        state = WAIT;
        next_state = LOAD_MODE_REG;
      end

      LOAD_MODE_REG:begin
        cmd = CMD_LOAD_MODE_REG;

        addr = {5'b00_1_00, 3'd2,4'b0_000}; // 12 bits

        //13 bits:
        // 3 bits. Reserved: Los 3 primeros bits estan reservados para futuras compatibilidades y se dejan a 0
        // 1 bit. WB: Write Burst Mode. 0 para ráfagas y 1 para no tener ráfagas.
        // 2 bits. Op Mode. 00 para modo estandar.
        // 3 bits. CAS Lantecy. Depende del chip q tengamos -75 o -7E
        // 1 bit. BT: Burst Type. 0 Secuencial y 1 intercalado
        // 3 bits. Burst Length. Tamano de la rafaga.



        next_cmd = CMD_NO_OP;
        delay_ctr = 2 - 2;
        state = WAIT;
        next_state = IDLE;
        refresh_ctr = 0;
        refresh_flag = 0;
      end

      IDLE: begin
        //data dir for reading mode
        //not read data valid
        //checking for refresh status if it is requested then refresh
        //else check for read and writE requested
        //if requested, check if the row is opened (by check the previous bank address and row address)
        //not opened then opened
        //opend => go to read or wriTE
        //if write load data first
        data_dir = 0;   //leemos
        sys_data_from_sdram_valid_reg = 0;  //no hay dato valido
        sys_write_done_reg = 0;             //no hay dato valido
        if (refresh_flag) begin             //si refresh flag está activa
          state = PRECHARGE;
          next_state = REFRESH;
          refresh_flag = 0; // reset refresh flag
          //set a10 = 1 to precharge all banks
          addr[10] = 1;
        end else begin
          if (sys_read_rq|sys_write_rq) begin 
            if (sys_addr[13:0] == save_addr[13:0]) begin
              if (row_opend) begin
                if (sys_read_rq) begin state = READ; end
                else if (sys_write_rq) begin 
                  state = WRITE; 
                  save_data = sys_data_to_sdram; //load data prepare to write
                end
              end
            end else begin
              if (sys_write_rq) save_data = sys_data_to_sdram;
              state = ACTIVATE;
            end
          end
        end

      end

      REFRESH:begin
        cmd = CMD_REFRESH;
        delay_ctr = 9 - 2;
        next_cmd = CMD_NO_OP;
        state = WAIT;
        next_state = IDLE;
      end

      ACTIVATE:
        begin
          save_addr[13:0] = sys_addr[13:0];
          row_opend = 0;
          cmd = CMD_ACTIVE;
          addr = sys_addr[13:0];
          next_cmd = CMD_NO_OP;
          delay_ctr = 2 - 2;
          state = WAIT;
          if (sys_read_rq)
            next_state = READ;
          else if (sys_write_rq)
            next_state = WRITE;
        end

      READ: begin
        cmd = CMD_READ;
        addr[7:0] = sys_addr[21:14];
        addr[11:8] = 4'b0010;
        delay_ctr = 3 - 2;
        state = WAIT;
        next_cmd = CMD_NO_OP;
        next_state = READ_RES;
      end

      READ_RES: begin
        state = IDLE;
        data = sdram_dq;
        sys_data_from_sdram_valid_reg = 1;
      end


      WRITE: begin
        cmd = CMD_WRITE;
        addr[8:0] = sys_addr[21:14];
        addr[12:9] = 4'b0010;
        state =  IDLE;
        data_dir = 1;
        sys_write_done_reg = 1;
      end

      PRECHARGE: begin
        cmd = CMD_PRECHARGE;
        addr[10] = 1;
        state = REFRESH;

      end

      default : state = INIT;

    endcase

  end

endmodule

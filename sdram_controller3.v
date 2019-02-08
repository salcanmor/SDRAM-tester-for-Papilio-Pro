`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:43:55 02/03/2019 
// Design Name: 
// Module Name:    sdram_controller3 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module sdram_controller3(
  sys_clk, sys_reset, sys_addr, sys_data_to_sdram, sys_data_from_sdram, sys_data_from_sdram_valid, rw, in_valid, out_valid, busy,
  sdram_clk, sdram_cke, sdram_addr, sdram_dq, sdram_ba, sdram_dqmh_n, sdram_dqml_n, sdram_cs_n, sdram_we_n, sdram_ras_n, sdram_cas_n
);


  // HOST interface 
  input wire sys_clk;                     // Clock to the SDRAM controller
  input wire sys_reset;                   // Reset for the controller
  input wire [21:0] sys_addr;             // Address bus to SDRAM. 22 bits = [ 12 row addr + 8 column addr + 2 BA ]
  //  [21:10] 12 bits row address, [9:2] 8 bits col address, [1:0] 2 bits bank

  input wire [15:0] sys_data_to_sdram;    // Data to be written to SDRAM
          input rw;               // 1 = write, 0 = read
			 
			         input in_valid;         // pulse high to initiate a read/write
        output out_valid;        // pulses high when data from read is valid


  //input wire sys_write_rq;                // Operation (WRITE) request signal (active high) 
  //input wire sys_read_rq;                 // Operation (READ) request signal (active high)

  output [15:0] sys_data_from_sdram;  		// Data read from SDRAM
  output wire sys_data_from_sdram_valid; 	// Valid data read flag
//  output wire sys_write_done;					//	Write done flag

  //  SDRAM interface
  output wire sdram_clk;                  // Clock input to SDRAM. All input signals are referenced to positive edge of CLK
  output wire sdram_cke;   					// Clock enable
  output wire [11:0] sdram_addr;          // Address bus to SDRAM
  output wire [1:0] sdram_ba;					//	Bank address
  output sdram_dqmh_n;              		// mask for high byte
  output sdram_dqml_n;             			//	mask for low byte
  output wire sdram_cs_n;                 // Chip select
  output wire sdram_we_n;                 // Write enable
  output wire sdram_ras_n;                // Row address strobe
  output wire sdram_cas_n;                // Column address strobe
  output busy;										//	Busy signal

  inout tri [15:0] sdram_dq;					//	Input/Output bus for receving/sending data from/to the SDRAM


  //	Commands for the SDRAM (table 14 from datasheet)

  localparam CMD_UNSELECTED		= 4'b1000;
  localparam CMD_NOP           	= 4'b0111;
  localparam CMD_ACTIVE        	= 4'b0011;
  localparam CMD_READ          	= 4'b0101;
  localparam CMD_WRITE         	= 4'b0100;
  localparam CMD_BURST_TERMINATE	= 4'b0110;
  localparam CMD_PRECHARGE     	= 4'b0010;
  localparam CMD_REFRESH       	= 4'b0001;
  localparam CMD_LOAD_MODE_REG 	= 4'b0000;


  //	State of the Finite State Machine

  localparam STATE_SIZE = 4;
  localparam  INIT = 0,
  WAIT = 1,
  PRECHARGE_INIT = 2,
  REFRESH_INIT_1 = 3,
  REFRESH_INIT_2 = 4,
  LOAD_MODE_REG = 5,
  IDLE = 6,
  REFRESH = 7,
  ACTIVATE = 8,
  READ = 9,
  READ_RES = 10,
  WRITE = 11,
  PRECHARGE = 12;

  wire sdram_clk_ddr;

  // 180 degree phase delayed sdram clock output

  ODDR2 #(
    .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
    .INIT(1'b0),    			// Sets initial state of the Q output to 1'b0 or 1'b1
    .SRTYPE("SYNC") 			// Specifies "SYNC" or "ASYNC" set/reset
  ) ODDR2_inst (
    .Q(sdram_clk_ddr),   	// 1-bit DDR output data
    .C0(sys_clk),   			// 1-bit clock input
    .C1(~sys_clk),   			// 1-bit clock input
    .CE(1'b1), 					// 1-bit clock enable input
    .D0(1'b0), 					// 1-bit data input (associated with C0)
    .D1(1'b1), 					// 1-bit data input (associated with C1)
    .R(1'b0),   				// 1-bit reset input
    .S(1'b0)    				// 1-bit set input
  );


  IODELAY2 #(
    .DATA_RATE("SDR"),               // "SDR" or "DDR" 
    .DELAY_SRC("ODATAIN"),           // "IO", "ODATAIN" or "IDATAIN" 
    .IDELAY_MODE("NORMAL"),          // "NORMAL" or "PCI" 
    .IDELAY_TYPE("FIXED"),           // "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
    // or "DIFF_PHASE_DETECTOR" 
    .IDELAY_VALUE(0),                // Amount of taps for fixed input delay (0-255)
    .ODELAY_VALUE(100)              // Amount of taps fixed output delay (0-255)
  )
  IODELAY2_inst (
    .BUSY(),         				// 1-bit output: Busy output after CAL
    .DATAOUT(),   					// 1-bit output: Delayed data output to ISERDES/input register
    .DATAOUT2(), 					// 1-bit output: Delayed data output to general FPGA fabric
    .DOUT(sdram_clk),         	// 1-bit output: Delayed data output
    .TOUT(),         				// 1-bit output: Delayed 3-state output
    .CAL(1'b0),           		// 1-bit input: Initiate calibration input
    .CE(1'b0),             		// 1-bit input: Enable INC input
    .CLK(1'b0),           		// 1-bit input: Clock input
    .IDATAIN(1'b0),   			// 1-bit input: Data input (connect to top-level port or I/O buffer)
    .INC(1'b0),           		// 1-bit input: Increment / decrement input
    .IOCLK0(1'b0),     			// 1-bit input: Input from the I/O clock network
    .IOCLK1(1'b0),     			// 1-bit input: Input from the I/O clock network
    .ODATAIN(sdram_clk_ddr),   // 1-bit input: Output data input from output register or OSERDES2.
    .RST(1'b0),           		// 1-bit input: Reset to zero or 1/2 of total delay period
    .T(1'b0)                	// 1-bit input: 3-state input signal
  );


  // Registers for SDRAM signals. 

  // The inputs of this module are registered in the register below
  // and then sent to the registers packaged them into IOB; IO buffer flip-flops. 

  reg cke_d;				//	Register for the SDRAM clock enable signal input
  reg [1:0] dqm_d;		//	Register for the SDRAM byte mask bus input
  reg [3:0] cmd_d;		//	Register for the SDRAM command bus input
  reg [1:0] ba_d;		//	Register for the SDRAM bank bus input
  reg [11:0] a_d;		//	Register for the SDRAM address bus input
  reg [15:0] dq_d;		//	Register for the data going to the SDRAM
  reg [15:0] dqi_d;	//	Register for the data coming from the SDRAM	


  // We want the output/input registers to be embedded in the
  // IO buffers so we set IOB to "TRUE". This is to ensure all
  // the signals are sent and received at the same time.
  (* IOB = "TRUE" *)
  reg cke_q;
  (* IOB = "TRUE" *)
  reg [1:0] dqm_q;
  (* IOB = "TRUE" *)
  reg [3:0] cmd_q;
  (* IOB = "TRUE" *)
  reg [1:0] ba_q;
  (* IOB = "TRUE" *)
  reg [11:0] a_q;
  (* IOB = "TRUE" *)
  reg [15:0] dq_q;
  (* IOB = "TRUE" *)
  reg [15:0] dqi_q;
  reg dq_en_d, dq_en_q;


  // Output assignments
  assign sdram_cke = cke_q;
  assign sdram_cs_n = cmd_q[3];
  assign sdram_ras_n = cmd_q[2];
  assign sdram_cas_n = cmd_q[1];
  assign sdram_we_n = cmd_q[0];
  assign sdram_dqml_n = dqm_q[0];
  assign sdram_dqmh_n = dqm_q[1];
  assign sdram_ba = ba_q;
  assign sdram_addr = a_q;
  assign sdram_dq = dq_en_q ? dq_q : 8'hZZ; // only drive when dq_en_q is 1


  reg [STATE_SIZE-1:0] state_d, state_q = INIT;			//	state_d is the next state. state_q is the current state
  reg [STATE_SIZE-1:0] next_state_d, next_state_q;		//	next_state_d is the next return state. next_state_q is the current state



  reg [21:0] addr_d, addr_q;									//	Intermediate register for the address
  reg [15:0] data_d, data_q;									//	Intermediate register for the data
  reg out_valid_d, out_valid_q;


  assign sys_data_from_sdram = data_q;
  assign busy = !ready_q;
  assign sys_data_from_sdram_valid = out_valid_q;


  reg [15:0] delay_ctr_d, delay_ctr_q;
  reg [1:0] byte_ctr_d, byte_ctr_q;

  reg [10:0] refresh_ctr_d, refresh_ctr_q;
  reg refresh_flag_d, refresh_flag_q;

  reg ready_d, ready_q;
  reg saved_rw_d, saved_rw_q;
  reg [21:0] saved_addr_d, saved_addr_q;					//	saved_addr_d  <-- to store the incoming address. saved_addr_q <-- to store the current address 
  reg [15:0] saved_data_d, saved_data_q;

  reg rw_op_d, rw_op_q;

  reg [3:0] row_open_d, row_open_q;
  reg [11:0] row_addr_d[3:0], row_addr_q[3:0];

  reg [2:0] precharge_bank_d, precharge_bank_q;
  integer i;





  always @* begin
    // Default values
    dq_d = dq_q;
    dqi_d = sdram_dq;
    dq_en_d = 1'b0; // normally keep the bus in high-Z
    cke_d = cke_q;
    cmd_d = CMD_NOP; // default to NOP
    dqm_d = 2'b00;
    ba_d = 2'd0;
    a_d = 12'd0;
    state_d = state_q;
    next_state_d = next_state_q;
    delay_ctr_d = delay_ctr_q;
    addr_d = addr_q;
    data_d = data_q;
    out_valid_d = 1'b0;
    precharge_bank_d = precharge_bank_q;
    rw_op_d = rw_op_q;
    byte_ctr_d = 2'd0;

    row_open_d = row_open_q;


    // row_addr is a 2d array and must be coppied this way
    for (i = 0; i < 4; i = i + 1)
      row_addr_d[i] = row_addr_q[i];



    // The data in the SDRAM must be refreshed periodically.
    // This conter ensures that the data remains intact.
    // 	The period of 100 MHz is 10 ns.
    //    15.625 us = 15625 ns
    // 	Therefore 15625/10 = 1.562,5 clock cycles. Therefore, it is necessary to emit the refresh every 1.562,5 maximum. In other case, we'll lose the data.
    // 	However, we're going to release it 32 cycles before (1530), just for safety.

        refresh_flag_d = refresh_flag_q;
        refresh_ctr_d = refresh_ctr_q + 1'b1;
    if (refresh_ctr_q  > 11'd1530) begin      
      refresh_ctr_d   = 11'd0;
      refresh_flag_d  = 1'b1;
    end


    saved_rw_d = saved_rw_q;
    saved_data_d = saved_data_q;
    saved_addr_d = saved_addr_q;
    ready_d = ready_q;



    // This is a queue of 1 for read/write operations.
    // When the queue is empty we aren't busy and can
    // accept another request.
    if (ready_q && in_valid) begin
      saved_rw_d = rw;
      saved_data_d = sys_data_to_sdram;
      saved_addr_d = sys_addr;
      ready_d = 1'b0;
    end

    case (state_q)

      //============================== INITALIZATION ==============================

      INIT: begin
        ready_d = 1'b0;
        row_open_d = 4'b0;
        out_valid_d = 1'b0;
        a_d = 12'b0;						// bus de direcciones a 0
        ba_d = 2'b0;						// bancos a 
        cke_d = 1'b1;					// habilitamos la señal cke
        state_d = WAIT;					//siguiente estado
        delay_ctr_d = 14'd10100; // wait for 101us
        next_state_d = PRECHARGE_INIT;	//estado de retorno
        dq_en_d = 1'b0;				// normally keep the bus in high-Z	
      end

      WAIT: begin										// durante este estado metemos la operacion NOP
        delay_ctr_d = delay_ctr_q - 1'b1;		// restamos 1 al contador de retraso
        if (delay_ctr_q == 14'd0) begin
          state_d = next_state_q;
          if (next_state_q == WRITE) begin
            dq_en_d = 1'b1; // enable the bus early
            dq_d = data_q[7:0];
          end
        end
      end


      PRECHARGE_INIT: begin 
        cmd_d = CMD_PRECHARGE;				// aqui ya no usamos NOP, usamos el comando de precarga
        a_d[10] = 1'b1; // all banks		//	precargamos todos los bancos
        ba_d = 2'd0;
        state_d = WAIT;
        next_state_d = REFRESH_INIT_1;
        delay_ctr_d = 13'd2;					//tRP = 15 ns

      end


      REFRESH_INIT_1: begin
        cmd_d = CMD_REFRESH;
        state_d = WAIT;
        delay_ctr_d = 13'd7;					//tRFC = 66ns
        next_state_d = REFRESH_INIT_2;

      end


      REFRESH_INIT_2: begin
        cmd_d = CMD_REFRESH;
        state_d = WAIT;
        delay_ctr_d = 13'd7;					//tRFC = 66ns
        next_state_d = LOAD_MODE_REG;

      end

      LOAD_MODE_REG: begin
        cmd_d = CMD_LOAD_MODE_REG;
        ba_d = 2'b0;
        // Reserved, Burst Access, Standard Op, CAS = 2, Sequential, Burst = 0
        a_d = {3'b000, 1'b0, 2'b00, 3'b010, 1'b0, 3'b000}; //010
        state_d = WAIT;
        delay_ctr_d = 13'd2;					// tMRD = 2 tCK
        next_state_d = IDLE;
        refresh_flag_d = 1'b0;
        refresh_ctr_d = 10'b1;			// Seteamos a 1 el contador para refresco
        ready_d = 1'b1;
      end

      //============================== IDLE ==============================

      IDLE: begin
        if (refresh_flag_q) begin // we need to do a refresh
          state_d = PRECHARGE;
          next_state_d = REFRESH;
          precharge_bank_d = 3'b100; // all banks
          refresh_flag_d = 1'b0; // clear the refresh flag
        end else if (!ready_q) begin // operation waiting. Nos quedamos esperando a que alguien meta dato/dirección y active in_valid
          ready_d = 1'b1; // clear the queue
          rw_op_d = saved_rw_q; // save the values we'll need later. AQuí guardamos en un reg el valor del flag de lectura/escritura
          addr_d = saved_addr_q;	// AQuí guardamos en un reg el valor del flag de lectura/escritura

          if (saved_rw_q) // Write // Si tenemos una escritura
            data_d = saved_data_q;	// También guardamos en un reg el valor del dato a escribir

          // if the row is open we don't have to activate it
          if (row_open_q[saved_addr_q[9:8]]) begin		//comprobamos que el banco en cuestión está abierto
            if (row_addr_q[saved_addr_q[9:8]] == saved_addr_q[21:10]) begin	//comprobamos que la row (fila) en cuestión está abierto
              // Row is already open
              if (saved_rw_q)				//hemos seleccionado ESCRITURA?
                state_d = WRITE;
              else
                state_d = READ;
            end else begin
              // A different row in the bank is open		//Si tenemos abierta una fila distinta a la que queremos, la cerramos y abrimos la fila que queremos
              state_d = PRECHARGE; // precharge open row
              precharge_bank_d = {1'b0, saved_addr_q[9:8]};	//le metemos el 0 para q no cierre todo, sino solo la fila en cuestion
              next_state_d = ACTIVATE; // open current row
            end
          end else begin
            // no rows open
            state_d = ACTIVATE; // open the row
          end
        end
      end



      ///// REFRESH /////
      REFRESH: begin
        cmd_d = CMD_REFRESH;
        state_d = WAIT;
        delay_ctr_d = 13'd6; // gotta wait 7 clocks (66ns) ////tRFC = 66ns
        next_state_d = IDLE;
      end

      ///// ACTIVATE /////
      ACTIVATE: begin
        cmd_d = CMD_ACTIVE;
        a_d = addr_q[21:10];
        ba_d = addr_q[9:8];
        delay_ctr_d = 13'd0;
        state_d = WAIT;

        if (rw_op_q)
          next_state_d = WRITE;
        else
          next_state_d = READ;

        row_open_d[addr_q[9:8]] = 1'b1; // row is now open // guardamos qué banco está abierto
        row_addr_d[addr_q[9:8]] = addr_q[21:10];				//	guardamos qué row (fila) está abierta y en qué banco
      end


      ///// READ /////
      READ: begin
        cmd_d = CMD_READ;
        a_d = {4'b0, addr_q[7:0]}; 	// le metemos la columna
        ba_d = addr_q[9:8];
        state_d = WAIT;
        delay_ctr_d = 13'd2; // wait for the data to show up
        next_state_d = READ_RES;

      end

      READ_RES: begin
        data_d = dqi_q; // shift the data in
        out_valid_d = 1'b1;
        state_d = IDLE;
      end

      ///// WRITE /////
      WRITE: begin


        dq_d = data_q[7:0];
        dq_en_d = 1'b1; // enable out bus
        a_d = {4'b0, addr_q[7:0]}; 	// le metemos la columna
        ba_d = addr_q[9:8];

        if (byte_ctr_q == 2'd3) begin
          state_d = IDLE;
        end
      end



      ///// PRECHARGE /////
      PRECHARGE: begin
        cmd_d = CMD_PRECHARGE;
        a_d[10] = precharge_bank_q[2]; // all banks
        ba_d = precharge_bank_q[1:0];
        state_d = WAIT;
        delay_ctr_d = 13'd0;

        if (precharge_bank_q[2]) begin
          row_open_d = 4'b0000; // closed all rows
        end else begin
          row_open_d[precharge_bank_q[1:0]] = 1'b0; // closed one row
        end
      end

      default: state_d = INIT;
    endcase

  end



    always @(posedge sys_clk) begin
        if(sys_reset) begin
            cke_q <= 1'b0;
            dq_en_q <= 1'b0;
            state_q <= INIT;
            ready_q <= 1'b0;
        end else begin
            cke_q <= cke_d;
            dq_en_q <= dq_en_d;
            state_q <= state_d;
            ready_q <= ready_d;
        end

        saved_rw_q <= saved_rw_d;
        saved_data_q <= saved_data_d;
        saved_addr_q <= saved_addr_d;

        cmd_q <= cmd_d;
        dqm_q <= dqm_d;
        ba_q <= ba_d;
        a_q <= a_d;
        dq_q <= dq_d;
        dqi_q <= dqi_d;

        next_state_q <= next_state_d;
        refresh_flag_q <= refresh_flag_d;
        refresh_ctr_q <= refresh_ctr_d;
        data_q <= data_d;
        addr_q <= addr_d;
        out_valid_q <= out_valid_d;
        row_open_q <= row_open_d;
        for (i = 0; i < 4; i = i + 1)
            row_addr_q[i] <= row_addr_d[i];
        precharge_bank_q <= precharge_bank_d;
        rw_op_q <= rw_op_d;
        byte_ctr_q <= byte_ctr_d;
        delay_ctr_q <= delay_ctr_d;
    end
endmodule

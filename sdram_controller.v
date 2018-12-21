`timescale 1ns / 1ps

module sdram_controller2( sdram_cke, sdram_clk, sdram_cs_n, sdram_we_n, sdram_ras_n, sdram_cas_n, sdram_a, sdram_ba, sdram_udqm, sdram_ldqm, sdram_dq, sys_clk, sys_reset, sys_addr, sys_cmd, sys_data_in, sys_data_out);

  // sdram interface
  output wire sdram_cke;			//	 Clock enable
  output reg sdram_clk;          // Clock input to SDRAM. All input signals are referenced to positive edge of CLK
  
  //	BEGIN: Command signals that define current operation
  
  output wire sdram_cs_n;			//	Chip select
  output wire sdram_we_n;			//	Write enable
  output wire sdram_ras_n;			//	Row address strobe
  output wire sdram_cas_n;			//	Column address strobe
  
  //	END: Command signals that define current operation
  
  output wire [11:0] sdram_addr; // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
  output wire [1:0] sdram_ba;    // banco al que se accede

  output wire sdram_dqmh_n;      // mascara para byte alto o bajo
  output wire sdram_dqml_n;      // durante operaciones de escritura

  inout tri [15:0] sdram_dq

  // host interface

  input wire sys_clk;                // este reloj debe ser el doble del reloj de la SDRAM
  input wire sys_reset;              // normalmente conectado a la versión negada del pin "locked" del PLL/MMCM


  input wire [22:0] sys_addr,        // address to SDRAM (up to 16M addresses)

  input wire [22:0] sys_cmd,        // address to SDRAM (up to 16M addresses)
  input wire [15:0] sys_data_in,        // address to SDRAM (up to 16M addresses)
  input wire [15:0] sys_data_out,        // address to SDRAM (up to 16M addresses)

endmodule



`timescale 1ns / 1ps



module top
  ( 
    input wire clk,					///
    input wire reset,				///
    input wire data_in,				///
    output wire data_out,			///



    output wire sdram_clk,			///
    output wire sdram_cke,			///
    output wire sdram_cs_n,		///
    output wire sdram_we_n,	///
    output wire sdram_ras_n,	////
    output wire sdram_cas_n,		///
    output wire [11:0] sdram_addr,	///
    output wire [1:0] sdram_ba,	///
    output wire sdram_dqmh_n,		///
    output wire sdram_dqml_n,		///
  inout tri [15:0] sdram_dq			///

  );

  wire [7:0] r_data_bus;
  wire [7:0] w_data_bus;
 // wire [11:0] sdram_addr_bus;
   //  wire [1:0] sdram_ba_bus;


 wire [21:0] sys_addr_bus;
 wire  [15:0] sys_data_from_sdram_bus;
 wire  [15:0] sys_data_to_sdram_bus;


  wire button_wire;
  wire tx_ready;
  wire clk_100;


  clock_100mhz clock_100mhz
   (// Clock in ports
    .CLK_IN1(clk),      // IN
    // Clock out ports
    .CLK_OUT1(clk_100));    // OUT



  debouncer debouncer_unit (
    .clk(clk_100),     
    .PB(reset), 
    .PB_state(), 
    .PB_down(), 
    .PB_up(button_wire)
  );


  uart uart (
    .clk(clk_100), 
    .reset(button_wire), 
    .data_in(data_in), 
    .tx_start(tx_start), 
    .w_data(w_data_bus), 
    .data_out(data_out), 
    .rx_done_tick(rx_done_tick), 
    .tx_done_tick(tx_done_tick), 
    .tx_ready(tx_ready), 
    .r_data(r_data_bus)
  );


tester tester (
    .clk(clk_100), 
    .reset(button_wire), 
    .rx_done_tick(rx_done_tick), 
    .r_data(r_data_bus), 
    .w_data(w_data_bus), 
    .tx_start(tx_start), 
    .tx_ready(tx_ready), 
    .sys_addr(sys_addr_bus), 
    .sys_data_to_sdram(sys_data_to_sdram_bus), 
    .sys_data_from_sdram(sys_data_from_sdram_bus), 
    .sys_write_rq(sys_write_rq), 
    .sys_read_rq(sys_read_rq)
    );
	 
	 sdram_controller2 sdram_controller2 (
    .sys_clk(clk_100), 
    .sys_addr(sys_addr_bus), 
    .sys_data_to_sdram(sys_data_to_sdram_bus), 
    .sys_data_from_sdram(sys_data_from_sdram_bus), 
    .sys_data_from_sdram_valid(sys_data_from_sdram_valid), 
    .sys_write_done(sys_write_done), 
    .sys_write_rq(sys_write_rq), 
    .sys_read_rq(sys_read_rq), 
    .sdram_clk(sdram_clk), 
    .sdram_cke(sdram_cke), 
    .sdram_addr(sdram_addr), 
    .sdram_dq(sdram_dq), 
    .sdram_ba(sdram_ba), 
    .sdram_dqmh_n(sdram_dqmh_n), 
    .sdram_dqml_n(sdram_dqml_n), 
    .sdram_cs_n(sdram_cs_n), 
    .sdram_we_n(sdram_we_n), 
    .sdram_ras_n(sdram_ras_n), 
    .sdram_cas_n(sdram_cas_n), 
    .state_(state_)
    );

endmodule

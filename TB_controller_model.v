`timescale 1ns / 1ps

module TB_controller_model;


// Inputs
	reg sys_clk;
	reg sys_reset;
	reg [21:0] sys_addr;
	reg [15:0] sys_data_to_sdram;
	reg rw;
	reg in_valid;

	// Outputs
	wire [15:0] sys_data_from_sdram;
	wire sys_data_from_sdram_valid;
	wire out_valid;
	wire busy;
	wire sdram_clk;
	wire sdram_cke;
	wire [11:0] sdram_addr;
	wire [1:0] sdram_ba;
	wire sdram_dqmh_n;
	wire sdram_dqml_n;
	wire sdram_cs_n;
	wire sdram_we_n;
	wire sdram_ras_n;
	wire sdram_cas_n;

	// Bidirs
	wire [15:0] sdram_dq;



	
		// Instantiate the Unit Under Test (UUT)
	sdram_controller sdram_controller (
		.sys_clk(sys_clk), 
		.sys_reset(sys_reset), 
		.sys_addr(sys_addr), 
		.sys_data_to_sdram(sys_data_to_sdram), 
		.sys_data_from_sdram(sys_data_from_sdram), 
		.sys_data_from_sdram_valid(sys_data_from_sdram_valid), 
		.rw(rw), 
		.in_valid(in_valid), 
		.out_valid(out_valid), 
		.busy(busy), 
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
		.sdram_cas_n(sdram_cas_n)
	);	

	// Instantiate the Unit Under Test (UUT)
	sdr sdr (
		.Dq(sdram_dq), 
		.Addr(sdram_addr), 
		.Ba(sdram_ba), 
		.Clk(sdram_clk), 
		.Cke(sdram_cke), 
		.Cs_n(sdram_cs_n), 
		.Ras_n(sdram_ras_n), 
		.Cas_n(sdram_cas_n), 
		.We_n(sdram_we_n), 
		.Dqm({sdram_dqmh_n, sdram_dqml_n})
	);
	
	
	
initial begin
		// Initialize Inputs
		sys_clk = 0;
		sys_reset = 1;
		sys_addr = 0;
		sys_data_to_sdram = 0;
		rw = 0;
		in_valid = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		sys_reset = 0;
		#150005;
		rw = 1;
		sys_addr = 22'b0000000001110000000000;
		sys_data_to_sdram = 16'b0011001100110011;
		in_valid = 1;
		#10;
				rw = 0;
		in_valid = 0;

#100;
		in_valid = 1;
				rw = 0;
		sys_addr = 22'b0000000001110000000000;

#10;
		in_valid = 0;

#1000;
$finish;


	end

always #5 sys_clk = ~ sys_clk;
      
endmodule

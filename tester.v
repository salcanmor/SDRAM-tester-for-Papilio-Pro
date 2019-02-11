`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.01.2019 20:27:30
// Design Name: 
// Module Name: tester
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tester(clk, reset, rx_done_tick, r_data, w_data, tx_start, tx_ready, sys_addr, sys_data_to_sdram, sys_data_from_sdram, sys_write_rq, sys_read_rq, sys_data_from_sdram_valid);

  input wire clk;
  input wire reset;
  input wire rx_done_tick;
  input wire [7:0] r_data;
  output reg [7:0] w_data;
  output reg tx_start;
  input wire tx_ready;
  
  input wire sys_data_from_sdram_valid;

  output  [21:0] sys_addr;
  output  [15:0] sys_data_to_sdram;

  input [15:0] sys_data_from_sdram;

  output reg sys_write_rq;
  output reg sys_read_rq;

  // state declaration for the FSM
  localparam [3:0]
  bienvenida                =   4'd0,         //  Here I show the main menu.
  idle_and_receive          =   4'd1,         //  Wait till the user select any option (1, 2 or 3). The option is store in a register.
  seleccion                 =   4'd2,         //  We check which option was selected.
  escritura                 =   4'd3,         //  We have selected write operation, so that we show a message to enter the input data value.
  escritura2                =   4'd4,         //  The entered data is stored in both formats ASCII and binary.
  escritura3                =   4'd5,         //  We show a message to enter the address value.
  escritura4                =   4'd6,         //  The entered data is stored in both formats ASCII and binary.
  pintar_datos_escritura    =   4'd7,         //  We print the 2 previous entered data

  lectura                   =   4'd8,         //  We have selected read operation, so that we show a message to enter the address value.
  lectura2                  =   4'd9,         //  The entered data is stored in both formats ASCII and binary.
  pintar_datos_lectura      =   4'd10,        //  We print the previous entered data
  activar_flag_lectura      =   4'd11,        //  We send read request flag
  senal_valid      =   4'd12;        //  We send read request flag


  //	signal declaration
  reg [3:0] state_reg;
  reg [7:0] rx_buffer;
  reg[2:0] count_tx_ready;

  reg[7:0]count_write;
  reg[8:0]count;
  reg [15:0]dato_binario_a_escribir;
  reg [21:0]dato_binario2;
  reg [21:0]dato_binario3;
  wire [127:0] buffer_data_s2f_r;

  always@(posedge clk, posedge reset)
    if(reset)begin
      sys_write_rq<=0;;
      sys_read_rq<=0;;
      state_reg<=bienvenida;
      tx_start<=0;
      count_write <= 0;
      count_tx_ready <= 0;
    end
  else 

    case (state_reg)
      bienvenida:begin
		      sys_write_rq<=0;;
      sys_read_rq<=0;;

        if (tx_ready)
          count_tx_ready <= count_tx_ready + 1'b1;
        else
          count_tx_ready <= 0;
        if (count_write < 129) //ultimo +1
          if(count_tx_ready == 7)begin
            count_write <= count_write + 1'b1;
            tx_start<=1'b1;
            case(count_write)
              128: w_data<=8'b00001101;
              127: w_data<="d";
              126: w_data<="a";
              125: w_data<="e";
              124: w_data<="R";
              123: w_data<="-";
              122: w_data<="2";
              121: w_data<=8'b00001001;
              120: w_data<=8'b00001101;
              119: w_data<="e";
              118: w_data<="t";
              117: w_data<="i";//8'b00001101
              116: w_data<="r";
              115: w_data<="W";
              114: w_data<="-";
              113: w_data<="1";
              112: w_data<=8'b00001001;
              111: w_data<=8'b00001101;
              110: w_data<=":";
              109: w_data<="s";
              108: w_data<="n";
              107: w_data<="o";
              106: w_data<="i";
              105: w_data<="t";
              104: w_data<="p";
              103: w_data<="O";
              102: w_data<=8'b00001101;
              101: w_data<=8'b00001101;
              100: w_data<="-";
              99: w_data<="-";
              98: w_data<="-";
              97: w_data<="-";
              96: w_data<="-";
              95: w_data<="-";
              94: w_data<="-";
              93: w_data<="-";
              92: w_data<="-";
              91: w_data<="-";
              90: w_data<="-";
              89: w_data<="-";
              88: w_data<="-";
              87: w_data<="-";
              86: w_data<="-";
              85: w_data<="-";
              84: w_data<="-";
              83: w_data<="-";
              82: w_data<="-";
              81: w_data<="-";
              80: w_data<="-";
              79: w_data<="-";
              78: w_data<="-";
              77: w_data<="-";
              76: w_data<="-";
              75: w_data<="-";
              74: w_data<="-";
              73: w_data<="-";
              72: w_data<="-";
              71: w_data<="-";
              70: w_data<="-";
              69: w_data<="-";
              68: w_data<="-";
              67: w_data<="-";
              66: w_data<="-";
              65: w_data<="-";
              64: w_data<="-";
              63: w_data<="-";
              62: w_data<="-";
              61: w_data<="-";
              60: w_data<="-";
              59: w_data<="-";          
              58: w_data<="-";
              57: w_data<="-";
              56: w_data<=8'b00001101;
              55: w_data<=")";
              54: w_data<="o";
              53: w_data<="n";
              52: w_data<="e";
              51: w_data<="r";
              49: w_data<="o";
              48: w_data<="M";
              47: w_data<=" ";
              46: w_data<="s";
              45: w_data<="a";
              44: w_data<="n";
              43: w_data<="a";
              42: w_data<="C";
              41: w_data<=" ";
              40: w_data<="r";
              39: w_data<="o";
              38: w_data<="d";
              37: w_data<="a";
              36: w_data<="v";
              35: w_data<="l";
              34: w_data<="a";
              33: w_data<="S";
              32: w_data<=" ";
              31: w_data<="y";
              30: w_data<="b";
              29: w_data<="(";
              28: w_data<=" ";
              27: w_data<="o";
              26: w_data<="r";
              25: w_data<="P";
              24: w_data<=" ";
              23: w_data<="o";
              22: w_data<="i";//8'b00001101
              21: w_data<="l";
              20: w_data<="i";
              19: w_data<="p";
              18: w_data<="a";
              17: w_data<="P";
              16: w_data<=" ";
              15: w_data<="R";
              14: w_data<="O";
              13: w_data<="F";
              12: w_data<=" ";
              11: w_data<="R";
              10: w_data<="E";
              9: w_data<="T";
              8: w_data<="S";
              7: w_data<="E";
              6: w_data<="T";
              5: w_data<=" ";
              4: w_data<="M";
              3: w_data<="A";
              2: w_data<="R";
              1: w_data<="D";
              0: w_data<="S";
              default: w_data<=8'b0;
            endcase
          end
        else
          begin
            tx_start<=1'b0;
          end
        else
          begin
            state_reg<=idle_and_receive;
            count_write <= 0;
            tx_start<=1'b0;
            count_tx_ready <= 0;
          end	
      end


      idle_and_receive: 
        begin 
          tx_start<=0;
          if(rx_done_tick)begin
            tx_start<=0;
            rx_buffer<=r_data;
            state_reg<=seleccion;
          end 
        end


      seleccion:
        begin

          tx_start<=1;
          if(rx_buffer == 8'b00110001)  // input: 1. escritura
            // state_reg<=escritura;
            begin  //w_data<="W";     
              state_reg<=escritura; end    

          else    if(rx_buffer == 8'b00110010)  // input: 2. lectura
            //state_reg<=lectura;
            begin     state_reg<=lectura;
            end   
          else  state_reg<=seleccion;

        end



      escritura:
        begin

          if (tx_ready)
            count_tx_ready <= count_tx_ready + 1'b1;
          else
            count_tx_ready <= 0;
          if (count_write < 33) //ultimo +1
            if(count_tx_ready == 7)begin
              count_write <= count_write + 1'b1;
              tx_start<=1'b1;
              case(count_write)

                32: w_data<=":";
                31: w_data<="n";
                30: w_data<="e";
                29: w_data<="t";
                28: w_data<="t";
                27: w_data<="i";
                26: w_data<="r";
                25: w_data<="w";
                24: w_data<=" ";
                23: w_data<="e";
                22: w_data<="b";//8'b00001101
                21: w_data<=" ";
                20: w_data<="o";
                19: w_data<="t";
                18: w_data<=" ";
                17: w_data<="a";
                16: w_data<="t";
                15: w_data<="a";
                14: w_data<="d";
                13: w_data<=" ";
                12: w_data<="r";
                11: w_data<="e";
                10: w_data<="t";
                9: w_data<="n";
                8: w_data<="E";
                7: w_data<="-";
                6: w_data<=8'b00001101;
                5: w_data<="E";
                4: w_data<="T";
                3: w_data<="I";
                2: w_data<="R";
                1: w_data<="W";
                0: w_data<=8'b00001101;
                default: w_data<=8'b0;
              endcase
            end
          else
            begin
              tx_start<=1'b0;
            end
          else
            begin
              state_reg<=escritura2;   //<<<--- cambiar esto por escritura2
              count_write <= 0;
              tx_start<=1'b0;
              count_tx_ready <= 0;

            end	
        end



      escritura2:begin


        tx_start<=0;

        // if(rx_done_tick && count==7)// if the byte number 20 is received 
        if(rx_done_tick && count==15)// if the byte number 16 is received 

          begin

            dato_binario_a_escribir <= {dato_binario_a_escribir[14:0], r_data[0]};

            count<=0;   // reset the counter
            w_data<=r_data;
            tx_start<=1;

            state_reg<=escritura3;  // go to state s1
            //     rx_buffer <= {rx_buffer[55:0],r_data}; // shift in last received byte
          end
        else if(rx_done_tick) // if a byte is received
          begin

            if (r_data[7:1] == 7'h18)begin  // si lo recibido es "0" o "1"...
              dato_binario_a_escribir <= {dato_binario_a_escribir[14:0], r_data[0]};


              count<=count+1'b1; // increment byte indicating counter
              w_data<=r_data;
              tx_start<=1;

              state_reg<=escritura2;              
              //  rx_buffer <= {rx_buffer[55:0],r_data}; // shift in the received byte
            end
            else             state_reg<=escritura2;              



          end

      end



      escritura3:
        begin

          if (tx_ready)
            count_tx_ready <= count_tx_ready + 1'b1;
          else
            count_tx_ready <= 0;
          if (count_write < 16) //ultimo +1
            if(count_tx_ready == 7)begin
              count_write <= count_write + 1'b1;
              tx_start<=1'b1;
              case(count_write)

                15: w_data<=":";
                14: w_data<="s";
                13: w_data<="s";
                12: w_data<="e";
                11: w_data<="r";
                10: w_data<="d";
                9: w_data<="d";
                8: w_data<="a";
                7: w_data<=" ";
                6: w_data<="r";
                5: w_data<="e";
                4: w_data<="t";
                3: w_data<="n";
                2: w_data<="E";
                1: w_data<="-";
                0: w_data<=8'b00001101;
                default: w_data<=8'b0;
              endcase
            end
          else
            begin
              tx_start<=1'b0;
            end
          else
            begin
              state_reg<=escritura4;
              count_write <= 0;
              tx_start<=1'b0;
              count_tx_ready <= 0;
            end    
        end

      escritura4:begin
        tx_start<=0;
        if(rx_done_tick && count==21)// if the byte number 20 is received 
          begin
            dato_binario2 <= {dato_binario2[20:0], r_data[0]};
            count<=0;   // reset the counter
            w_data<=r_data;
            tx_start<=1;
            state_reg<=pintar_datos_escritura;  // go to state s1
          end
        else if(rx_done_tick) // if a byte is received
          begin
            if (r_data[7:1] == 7'h18)begin  // si lo recibido es "0" o "1"... SINO NO ESCRIBIMOS NADA Y SEGUIMOS ESPERANDO UN 0 ? 1
              dato_binario2 <= {dato_binario2[20:0], r_data[0]};
              count<=count+1'b1; // increment byte indicating counter
              w_data<=r_data;
              tx_start<=1;
              state_reg<=escritura4;              
            end
            else         
              state_reg<=escritura4;              
          end
      end

      pintar_datos_escritura:
        begin 		sys_write_rq<= 1;

          if (tx_ready)
            count_tx_ready <= count_tx_ready + 1'b1;
          else
            count_tx_ready <= 0;
          if (count_write < 29) //ultimo +1
            if(count_tx_ready == 7)begin
              count_write <= count_write + 1'b1;
              tx_start<=1'b1;
              case(count_write)
                28: w_data<=8'b00001101;
                27: w_data<=8'b00001101;
                26: w_data<="!";
                25: w_data<="y";
                24: w_data<="l";
                23: w_data<="l";
                22: w_data<="u";
                21: w_data<="f";
                20: w_data<="s";
                19: w_data<="s";
                18: w_data<="e";
                17: w_data<="c";
                16: w_data<="c";
                15: w_data<="u";
                14: w_data<="s";
                13: w_data<=" ";
                12: w_data<="n";
                11: w_data<="e";
                10: w_data<="t";
                9: w_data<="t";
                8: w_data<="i";
                7: w_data<="r";
                6: w_data<="w";
                5: w_data<=" ";
                4: w_data<="a";
                3: w_data<="t";
                2: w_data<="a";
                1: w_data<="D";
                0: w_data<=8'b00001101;
                default: w_data<=8'b0;
              endcase
            end
          else
            begin
              tx_start<=1'b0;
            end
          else
            begin
              state_reg<=bienvenida;
              count_write <= 0;
              tx_start<=1'b0;
              count_tx_ready <= 0;
            end    
        end

      lectura:
        begin
          if (tx_ready)
            count_tx_ready <= count_tx_ready + 1'b1;
          else
            count_tx_ready <= 0;
          if (count_write < 32) //ultimo +1
            if(count_tx_ready == 7)begin
              count_write <= count_write + 1'b1;
              tx_start<=1'b1;
              case(count_write)
                31: w_data<=":";
                30: w_data<="d";
                29: w_data<="a";
                28: w_data<="e";
                27: w_data<="r";
                26: w_data<=" ";
                25: w_data<="e";
                24: w_data<="b";//8'b00001101
                23: w_data<=" ";
                22: w_data<="o";
                21: w_data<="t";
                20: w_data<=" ";
                19: w_data<="s";
                18: w_data<="s";
                17: w_data<="e";
                16: w_data<="r";
                15: w_data<="d";
                14: w_data<="d";
                13: w_data<="a";
                12: w_data<=" ";
                11: w_data<="r";
                10: w_data<="e";
                9: w_data<="t";
                8: w_data<="n";
                7: w_data<="E";
                6: w_data<="-";
                5: w_data<=8'b00001101;
                4: w_data<="D";
                3: w_data<="A";
                2: w_data<="E";
                1: w_data<="R";
                0: w_data<=8'b00001101;
                default: w_data<=8'b0;
              endcase
            end
          else
            begin
              tx_start<=1'b0;
            end
          else
            begin
              state_reg<=lectura2;   //<<<--- cambiar esto por escritura2
              count_write <= 0;
              tx_start<=1'b0;
              count_tx_ready <= 0;
            end	
        end

      lectura2:begin
        tx_start<=0;
        if(rx_done_tick && count==21)// if the byte number 20 is received 
          begin
            dato_binario3 <= {dato_binario3[20:0], r_data[0]};
            count<=0;   // reset the counter
            w_data<=r_data;
            tx_start<=1;
            state_reg<=activar_flag_lectura;  // go to state s1 			//<<<-----------------cambiar esto!!!
          end
        else if(rx_done_tick) // if a byte is received
          begin
            if (r_data[7:1] == 7'h18)  // si lo recibido es "0" o "1"...
              begin
                dato_binario3 <= {dato_binario3[20:0], r_data[0]};
                count<=count+1'b1; // increment byte indicating counter
                w_data<=r_data;
                tx_start<=1;
                state_reg<=lectura2;              
              end 
            else             
              state_reg<=lectura2;              
          end

      end

activar_flag_lectura:begin

      sys_read_rq<=1;
state_reg<=pintar_datos_lectura;
		end
		




      pintar_datos_lectura:
		
        begin        

		  sys_read_rq<=0;

          if (tx_ready)
            count_tx_ready <= count_tx_ready + 1;
          else
            count_tx_ready <= 0;
          if (count_write < 35)
            if(count_tx_ready == 7)begin
              count_write <= count_write + 1;
              tx_start<=1'b1;
              case(count_write)
                34: w_data<=8'b00001101;
                33: w_data<=8'b00001101;
                32: w_data<= buffer_data_s2f_r[7:0];
                31: w_data<= buffer_data_s2f_r[15:8];
                30: w_data<= buffer_data_s2f_r[23:16];
                29: w_data<= buffer_data_s2f_r[31:24];
                28: w_data<= buffer_data_s2f_r[39:32];
                27: w_data<= buffer_data_s2f_r[47:40];
                26: w_data<= buffer_data_s2f_r[55:48];
                25: w_data<= buffer_data_s2f_r[63:56];
                24: w_data<= buffer_data_s2f_r[71:64];
                23: w_data<= buffer_data_s2f_r[79:72];
                22: w_data<= buffer_data_s2f_r[87:80];
                21: w_data<= buffer_data_s2f_r[95:88];
                20: w_data<= buffer_data_s2f_r[103:96];
                19: w_data<= buffer_data_s2f_r[111:104];
                18: w_data<= buffer_data_s2f_r[119:112];
                17: w_data<= buffer_data_s2f_r[127:120];
                16: w_data<=" ";
                15: w_data<=":";
                14: w_data<="a";
                13: w_data<="t";
                12: w_data<="a";
                11: w_data<="d";
                10: w_data<=" ";
                9: w_data<="d";
                8: w_data<="e";
                7: w_data<="v";
                6: w_data<="e";
                5: w_data<="i";
                4: w_data<="r";
                3: w_data<="t";
                2: w_data<="e";
                1: w_data<="R";
                0: w_data<=8'b00001101;
                default: w_data<=8'b0;
              endcase
            end
          else
            begin
              tx_start<=1'b0;
            end
          else
            begin
              state_reg<=bienvenida;
              count_write <= 0;
              tx_start<=1'b0;
              count_tx_ready <= 0;
            end    
        end 
    endcase

  assign sys_addr = sys_read_rq ? dato_binario3 :
    (sys_write_rq ? dato_binario2 : 0);						 

  assign sys_data_to_sdram = (sys_write_rq) ? dato_binario_a_escribir : 16'hZZZZ;

  assign	buffer_data_s2f_r[7:0]		=	(sys_data_from_sdram[0])	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[15:8]		=	(sys_data_from_sdram[1])	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[23:16]	=	(sys_data_from_sdram[2])	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[31:24] 	=	(sys_data_from_sdram[3]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[39:32]	=	(sys_data_from_sdram[4]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[47:40] 	=	(sys_data_from_sdram[5]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[55:48] 	=	(sys_data_from_sdram[6])	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[63:56] 	=	(sys_data_from_sdram[7]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[71:64] 	=	(sys_data_from_sdram[8]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[79:72] 	=	(sys_data_from_sdram[9]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[87:80] 	=	(sys_data_from_sdram[10])  ? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[95:88] 	=	(sys_data_from_sdram[11]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[103:96] 	=	(sys_data_from_sdram[12]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[111:104] =	(sys_data_from_sdram[13]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[119:112] =	(sys_data_from_sdram[14]) 	? 8'b00110001 : 8'b00110000 ;
  assign	buffer_data_s2f_r[127:120] =	(sys_data_from_sdram[15]) 	? 8'b00110001 : 8'b00110000 ;


endmodule

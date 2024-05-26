`timescale 1ns/1ps
module template_tb();

//handle clock
parameter PERIOD = 83; //times timescale
parameter PERIOD_PLL = 27; //times timescale

parameter VALUE = 1000; // actual result of the conversion

reg clk_i;
reg clk_pll_i;

reg uart_rx_i;

reg rst_ni;
reg comp_i;

wire rdy_o;
wire start_o;
wire uart_tx_o;
wire [11:0] dac_o;

initial begin 
  clk_i = 1'b0;
  clk_pll_i = 1'b0;
  rst_ni = 1'b1;
  comp_i = 1'b0;

  #20 rst_ni = 1'b0;
  #20 rst_ni = 1'b1;
end

always
  #(PERIOD/2) clk_i = ~clk_i;

always
  #(PERIOD_PLL/2) clk_pll_i = ~clk_pll_i;

// comp_i checks if dac_o is greater than VALUE
always begin
    #1 comp_i = VALUE >= dac_o;
    // if (rdy_o) begin
    //     $display("Conversion complete, dac_o = %d, value = %d", dac_o, VALUE);
    //     $finish;
    // end
end

main dut (
    .rst_ni(rst_ni),
    .clk_i(clk_i),

    .clk_pll_i(clk_pll_i), // ONLY FOR TESTBENCH

    .uart_rx_i(uart_rx_i),
    .uart_tx_o(uart_tx_o),
    
    .comp_i(comp_i),
    .start_o(start_o),
    .rdy_o(rdy_o),
    .dac_o(dac_o)
);

//simulate the UART
parameter BAUD_DIVIDER = 16'h013F; //36.75MHz/115200baud = 319
parameter TEST_CHAR_NUMBER = 25;
integer char_count;
reg[TEST_CHAR_NUMBER*8:0] chars_to_send;
reg [10:0] tx_byte = 'b0;
reg [7:0] tx_char = 'b0;
reg [5:0] tx_count = 'b0;
reg [15:0] baud_div_counter = 'b0;
initial	
	begin
	uart_rx_i = 1'b1;
	tx_byte = {2'b11,"0",1'b0}; //stop bit, byte, start bit
	tx_count = 'b0;
	baud_div_counter = 'b0;
	chars_to_send = "asdfeL0asL1ddLALFLBas334 ";
	char_count = 0;
	tx_char = 'b0;
	end

always @ (posedge clk_pll_i)
begin
	if (baud_div_counter < BAUD_DIVIDER)
		begin
			baud_div_counter = baud_div_counter + 1;
		end
	else
		begin
			baud_div_counter = 0;
			if (tx_count < 10)
				begin
				uart_rx_i = tx_byte[0];
				tx_byte = tx_byte >> 1;
				tx_count = tx_count + 1;
				end
			else
				begin
				uart_rx_i = 1'b1; //idle
				tx_count = 'b0;
				tx_char = chars_to_send[TEST_CHAR_NUMBER*8:(TEST_CHAR_NUMBER-1)*8];
				tx_byte = {2'b11,tx_char,1'b0};
				chars_to_send = chars_to_send << 8;
				char_count = char_count + 1;
				end	
		end
end	

//handle simulation
parameter DURATION = 200000000; //times timescale
`define DUMPSTR(x) `"x.vcd`"
initial begin
  $dumpfile(`DUMPSTR(`VCD_OUTPUT));
  $dumpvars(0, template_tb);
   #(DURATION) $display("End of simulation, conversion never completed");
  $finish;
end	
	
endmodule
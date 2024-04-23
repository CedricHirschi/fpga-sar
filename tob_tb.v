`timescale 1ns/1ps
module template_tb();

//handle clock
parameter PERIOD = 10; //times timescale

parameter VALUE = 30000; // actual result of the conversion

reg clk_i;
reg rst_ni;
reg start_i;
reg comp_i;

wire rdy_o;
wire [15:0] dac_o;

initial begin 
  clk_i = 1'b0;
  rst_ni = 1'b1;
  start_i = 1'b0;
  comp_i = 1'b0;

  #20 rst_ni = 1'b0;
  #20 rst_ni = 1'b1;

  #20 start_i = 1'b1;
  #20 start_i = 1'b0;
end

always
  #(PERIOD/2) clk_i = ~clk_i;

// comp_i checks if dac_o is greater than VALUE
always begin
    #1 comp_i = VALUE >= dac_o;
    if (rdy_o) begin
        $display("Conversion complete, dac_o = %d, value = %d", dac_o, VALUE);
        $finish;
    end
end

top dut (
    .clk_i(clk_i),
    .start_i(start_i),
    .rst_ni(rst_ni),
    .comp_i(comp_i),
    .rdy_o(rdy_o),
    .dac_o(dac_o)
);

//handle simulation
parameter DURATION = 2000; //times timescale
`define DUMPSTR(x) `"x.vcd`"
initial begin
  $dumpfile(`DUMPSTR(`VCD_OUTPUT));
  $dumpvars(0, template_tb);
   #(DURATION) $display("End of simulation, conversion never completed");
  $finish;
end	
	
endmodule
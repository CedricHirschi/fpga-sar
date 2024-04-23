module top (
    input wire clk_i,                 // Clock input
    input wire start_i,               // Start conversion signal
    input wire rst_ni,               // Asynchronous reset
    input wire comp_i,      // Input from external analog comparator
    output wire rdy_o,              // Conversion complete signal
    output wire [15:0] dac_o      // Output to external R-2R ladder DAC
);

sar_adc #(
    .RESOLUTION(16)
) i_sar_adc (
    .clk_i(clk_i),
    .start_i(start_i),
    .rst_ni(rst_ni),
    .comp_i(comp_i),
    .rdy_o(rdy_o),
    .dac_o(dac_o)
);
    
endmodule
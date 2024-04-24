module main (
    input wire rst_ni,               // Asynchronous reset
    input wire clk_i,                 // Clock input

    input wire uart_rx_i,            // Input from external UART RX
    output wire uart_tx_o,           // Output to external UART TX
    
    input wire comp_i,      // Input from external analog comparator
    output wire start_o,              // Start conversion signal
    output wire rdy_o,              // Conversion complete signal
    output wire [11:0] dac_o      // Output to external R-2R ladder DAC
);

localparam CLK_FREQ = 36_750_000; // 36.75 MHz
localparam ADC_FREQ = 100_000; // 100 kHz

wire start_w;
wire rdy_w;
wire clk_div_w;
wire clk_pll_w;

pll i_pll (
    .clock_in(clk_i),
    .clock_out(clk_pll_w),
    .locked()
);

frequency_divider #(
    .CLK_FREQ(CLK_FREQ),
    .OUT_FREQ(ADC_FREQ)
) i_frequency_divider (
    .divided_o(clk_div_w),
    .clk_i(clk_pll_w),
    .rst_ni(rst_ni)
);

sar_adc #(
    .RESOLUTION(12)
) i_sar_adc (
    .clk_i(clk_div_w),
    .start_i(start_w),
    .rst_ni(rst_ni),
    .comp_i(comp_i),
    .rdy_o(rdy_w),
    .dac_o(dac_o)
);

uart_readout i_uart_readout (
    .clk_i(clk_pll_w),
    .reset_ni(rst_ni),
    .en_i(1'b1),
    .rx_i(uart_rx_i),
    .tx_o(uart_tx_o),
    .adc_start_o(start_w),
    // .mic_spi_sample(dac_o),
    // .mic_spi_sample_ready(rdy_w)
    .adc_sample(dac_o),
    .adc_sample_ready(rdy_w)
);

assign rdy_o = !rdy_w;
assign start_o = !start_w;

endmodule
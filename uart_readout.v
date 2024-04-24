module uart_readout (
    input wire clk_i,
    input wire reset_ni,
    input wire en_i,
    input wire rx_i,
    output wire tx_o,
    input wire [11:0] adc_sample,           // ADC sample input
    input wire adc_sample_ready,            // ADC sample ready signal
    output reg adc_start_o                  // Output signal to start ADC conversion
);

wire tx_byte_ready_o;
wire [7:0] tx_byte_o;
assign tx_byte_ready_o = tx_byte_ready_q;
assign tx_byte_o = tx_byte_q;
wire tx_busy;

// UART TX instance
uart_tx u_uart_tx (
    .clk_i(clk_i),
    .reset_ni(reset_ni),
    .tx_data_i(tx_byte_o),
    .en_i(tx_byte_ready_o),
    .busy_o(tx_busy),
    .tx_o(tx_o)
);

// UART RX instance
wire [7:0] temp_rx_data;
wire temp_tx_ready;
uart_rx u_uart_rx (
    .clk_i(clk_i),
    .reset_ni(reset_ni),
    .rx_i(rx_i),
    .en_i(en_i),
    .rx_data_o(temp_rx_data),
    .rx_ready_o(temp_tx_ready)
);

// Buffer ADC sample
reg [11:0] adc_sample_buffer_q;
always @(posedge clk_i or negedge reset_ni) begin
    if (!reset_ni) begin
        adc_sample_buffer_q <= 12'b0;
    end else if (adc_sample_ready) begin
        adc_sample_buffer_q <= adc_sample;
    end
end

// TX state machine definitions
reg [2:0] uart_state;
localparam STATE_REST = 3'b000,
           STATE_WAIT_FOR_CONVERT = 3'b001,
           STATE_TX_SAMPLE = 3'b010,
           STATE_WAIT = 3'b011,
           STATE_CR = 3'b100,
           STATE_WAIT_CR = 3'b101,
           STATE_LF = 3'b110,
           STATE_WAIT_LF = 3'b111;

reg tx_byte_ready_q;
reg [7:0] tx_byte_q;
reg [11:0] adc_shift_buffer_q;
reg [4:0] bit_count_q;
reg [15:0] delay_counter_q;
reg temp_tx_ready_old;

always @(posedge clk_i or negedge reset_ni) begin
    if (!reset_ni) begin
        uart_state <= STATE_REST;
        temp_tx_ready_old <= 1'b0;
        tx_byte_ready_q <= 1'b0;
        tx_byte_q <= 8'b0;
        adc_shift_buffer_q <= 12'b0;
        bit_count_q <= 5'b0;
        delay_counter_q <= 16'b0;
        adc_start_o <= 1'b0;  // Default state not triggering ADC
    end else begin
        temp_tx_ready_old <= temp_tx_ready;
        case (uart_state)
            STATE_REST: begin
                if (~temp_tx_ready_old & temp_tx_ready & (temp_rx_data == 8'h73)) begin
                    adc_start_o <= 1'b1; // Start ADC conversion
                    uart_state <= STATE_WAIT_FOR_CONVERT;
                end else begin
                    adc_start_o <= 1'b0; // Ensure ADC is not repeatedly triggered
                    tx_byte_q <= temp_rx_data;
                    tx_byte_ready_q <= temp_tx_ready;
                end
            end
            STATE_WAIT_FOR_CONVERT: begin
                if (adc_sample_ready) begin
                    adc_shift_buffer_q <= adc_sample_buffer_q;
                    uart_state <= STATE_TX_SAMPLE;
                end
            end
            STATE_TX_SAMPLE: begin
				adc_start_o <= 1'b0; // Ensure ADC is not repeatedly triggered
                if (bit_count_q < 12) begin
                    tx_byte_q <= (adc_shift_buffer_q[11] ? 8'h31 : 8'h30); // Convert binary to ASCII '0' or '1'
                    tx_byte_ready_q <= 1'b1;
                    adc_shift_buffer_q <= adc_shift_buffer_q << 1;
                    bit_count_q <= bit_count_q + 1;
                    uart_state <= STATE_WAIT;
                end else begin
                    bit_count_q <= 5'b0;
                    uart_state <= STATE_CR;
                end
            end
            STATE_WAIT: begin
                tx_byte_ready_q <= 1'b0;
                if (!tx_busy && delay_counter_q < 16'h013F) begin
                    delay_counter_q <= delay_counter_q + 1;
                end else if (!tx_busy) begin
                    delay_counter_q <= 16'b0;
                    uart_state <= STATE_TX_SAMPLE;
                end
            end
            STATE_CR: begin
                tx_byte_q <= 8'h0D;  // Carriage return
                tx_byte_ready_q <= 1'b1;
                uart_state <= STATE_WAIT_CR;
            end
            STATE_WAIT_CR,
            STATE_WAIT_LF: begin
                tx_byte_ready_q <= 1'b0;
                if (!tx_busy && delay_counter_q < 16'h013F) begin
                    delay_counter_q <= delay_counter_q + 1;
                end else if (!tx_busy) begin
                    delay_counter_q <= 16'b0;
                    uart_state <= (uart_state == STATE_WAIT_CR ? STATE_LF : STATE_REST);
                end
            end
            STATE_LF: begin
                tx_byte_q <= 8'h0A;  // Line feed
                tx_byte_ready_q <= 1'b1;
                uart_state <= STATE_WAIT_LF;
            end
            default: uart_state <= STATE_REST;
        endcase
    end
end

endmodule

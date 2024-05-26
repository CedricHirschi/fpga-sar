module uart_rx (
	input wire clk_i,
	input wire reset_ni,
	input wire rx_i,
	input wire en_i,
	output wire [7:0] rx_data_o,
	output wire rx_ready_o,
	output wire rx_div_clk_en_o
);

parameter BAUD_DIVIDER = 16'h013F; //36.75MHz/115200baud = 319
parameter RX_DEBOUNCING_BIT_NUMBER = 15;
parameter RX_DEBOUNCING_BIT_LOG2 = 4;

reg [RX_DEBOUNCING_BIT_NUMBER-1:0] rx_i_sampler_q;
reg [RX_DEBOUNCING_BIT_LOG2-1:0] rx_i_sum_d;
reg rx_i_debounced_q;
reg rx_i_old_q;
reg rx_active_q;

reg [15:0] clk_counter_q;
reg clk_en_baud_q;

reg [1:0] rx_state_q;
reg [1:0] rx_state_d;
parameter RX_STATE_IDLE = 2'b00;
parameter RX_STATE_RUNNING = 2'b01;

reg [3:0] rx_counter_q;
reg [3:0] rx_counter_d;
reg [7:0] rx_data_d;
reg [7:0] rx_data_q;
reg [7:0] rx_data_out_q;
reg rx_ready_out_q;

//filter rx_i for better stability: majority vote of 5 samples
integer i; //32 bit
always @ (posedge clk_i, negedge reset_ni)
    begin: RX_IN_DEBOUNCING
        if (!reset_ni)
            begin
            rx_i_sampler_q <= 'b1; //fill with ones
            rx_i_debounced_q <= 1'b1;
            end
        else
		    begin
            rx_i_sampler_q <= {rx_i_sampler_q[RX_DEBOUNCING_BIT_NUMBER-2:0], rx_i};
			rx_i_sum_d = 'b0; //fill with zeros
			for (i=0; i<RX_DEBOUNCING_BIT_NUMBER; i=i+1)
				rx_i_sum_d = rx_i_sum_d + rx_i_sampler_q[i];
			
			if (rx_i_sum_d > (RX_DEBOUNCING_BIT_NUMBER >> 1)) //more than half of the bits positive
				rx_i_debounced_q <= 1'b1;
			else
				rx_i_debounced_q <= 1'b0;
            
			end
	end
	
//generate frame start signal for logic
always @ (posedge clk_i, negedge reset_ni)
    begin: UART_FRAME_START
        if (!reset_ni)
            begin
            rx_i_old_q <= 1'b1;
            rx_active_q <= 1'b0;
            end
        else
            begin
            rx_i_old_q <= rx_i_debounced_q; //here we need <=, as the reg is used afterwards in this code block
            if ((rx_i_debounced_q == 1'b0) & (rx_i_old_q == 1'b1) & (rx_state_q == RX_STATE_IDLE) & (en_i == 1'b1)) //falling edge on rx_i_debounced_q
                rx_active_q <= 1'b1;
            else if ((rx_counter_q == 4'b0001) & (rx_state_q == RX_STATE_RUNNING) & (clk_en_baud_q == 1'b1))
                rx_active_q <= 1'b0;
			else
				rx_active_q <= rx_active_q;
            end
end

//clk divider for baud-rate
always @ (posedge clk_i, negedge reset_ni)
    begin: BAUDRATE_GENERATOR
        if(!reset_ni)
            begin
            clk_counter_q <= BAUD_DIVIDER >> 1;
            clk_en_baud_q <= 1'b0;
            end
        else
            begin
			if (rx_active_q)
				if (clk_counter_q < BAUD_DIVIDER-1)
					begin
					clk_counter_q <= clk_counter_q + 1;
					clk_en_baud_q <= 1'b0;
					end
				else
					begin
					clk_counter_q <= 16'h0000;
					clk_en_baud_q <= 1'b1;
					end
			else
				begin
				clk_counter_q <= BAUD_DIVIDER >> 1;
				clk_en_baud_q <= 1'b0;
				end
            end
    end

//uart rx state-machine (register)
always @ (posedge clk_i, negedge reset_ni)
    begin: STATEMACHINE_RX
        if (!reset_ni)
            begin
            rx_state_q <= RX_STATE_IDLE;
            rx_data_q <= 8'h00;
            rx_counter_q <= 4'h0;
            end
        else if (clk_en_baud_q) //only advance the statemachine with baud-rate speed
            begin
            rx_state_q <= rx_state_d;
            rx_data_q <= rx_data_d;
            rx_counter_q <= rx_counter_d;
            end
end
 
//uart rx state-machine (combinatoric)
always @ (reset_ni, rx_state_q, rx_active_q, rx_counter_q, rx_i_old_q, rx_data_q)
    begin: STATEMACHINE_RX_COMB
        if (!reset_ni)
            begin
            rx_state_d = RX_STATE_IDLE;
            rx_data_d = 8'h00;
            rx_counter_d = 4'b0000;
            end
        else 
			case(rx_state_q)
                RX_STATE_IDLE: 
					if (rx_active_q)
						begin
						rx_state_d = RX_STATE_RUNNING; //note: when moving to RX_STATE_RUNNING we loose the sample of the star bit, but not a problem yet
						rx_counter_d = 4'b1001; //preload counter (8+1 start bit)
						rx_data_d = 8'h00;
						end
					else
						begin
						rx_state_d = RX_STATE_IDLE;
						rx_counter_d = 4'b0000;
						rx_data_d = 8'h00;
						end
					
				RX_STATE_RUNNING:
					begin
					rx_counter_d = rx_counter_q - 1;
					rx_data_d = {rx_i_old_q, rx_data_q[7:1]};
					if(rx_counter_q != 4'b0001)
						rx_state_d = RX_STATE_RUNNING;
					else
						rx_state_d = RX_STATE_IDLE;
					end

                default:
					begin
					rx_state_d = RX_STATE_IDLE;
					rx_data_d = 8'h00;
					rx_counter_d = 4'b0000;
					end
            endcase
 
end

//output data from frame 
always @ (posedge clk_i, negedge reset_ni)
    begin: RX_OTPUT
        if (!reset_ni)
            begin
            rx_data_out_q <= 8'h00;
			rx_ready_out_q <= 1'b0;
            end
        else if ((rx_counter_d == 4'b0001) & (rx_state_q == RX_STATE_RUNNING) & (clk_en_baud_q == 1'b1))
            begin
            rx_data_out_q <= rx_data_d;
            rx_ready_out_q <= 1'b1;
            end
		else
            begin
            rx_data_out_q <= 8'h00;
			rx_ready_out_q <= 1'b0;
            end
end
assign rx_data_o = rx_data_out_q; 
assign rx_ready_o = rx_ready_out_q;

//debug:
assign rx_div_clk_en_o = clk_en_baud_q;

endmodule
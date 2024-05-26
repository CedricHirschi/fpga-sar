module uart_tx (
	input wire clk_i,
	input wire reset_ni,
	input wire [7:0] tx_data_i,
	input wire en_i,
	output wire tx_o,
	output wire busy_o
);

parameter BAUD_DIVIDER = 16'h013F; //36.75MHz/115200baud = 319

reg tx_output_d;
reg tx_output_q = 1'b1;

reg [15:0] clk_counter_q = 'b0;
reg clk_en_baud_q = 1'b0;

reg [9:0] tx_d; // 1 start bit, 8 bit data, 2 stop bit, no parity
reg [9:0] tx_q = 'b0; // 1 start bit, 8 bit data, 2 stop bit, no parity

reg busy_q = 1'b0;
reg [7:0] tx_data_q = 'b0;

reg [1:0] tx_state_q = TX_STATE_IDLE;
reg [1:0] tx_state_d;
reg [3:0] tx_counter_q = 'b0;
reg [3:0] tx_counter_d;
parameter TX_STATE_IDLE = 2'b00;
parameter TX_STATE_TRANSMIT = 2'b01;
 
 //handle busy flag:
always @ (posedge clk_i, negedge reset_ni)
    begin: BUSY_FLAG_GEN
        if (!reset_ni)
			begin
            busy_q <= 1'b0;
			tx_data_q <= 8'h00;
			end
        else if (!busy_q & en_i)
			begin
            busy_q <= 1'b1;
			tx_data_q <= tx_data_i; //buffer input
			end
        else if ((tx_counter_q == 4'b0000) & clk_en_baud_q & tx_state_d == TX_STATE_IDLE )
			begin
            busy_q <= 1'b0;
			tx_data_q <= 8'h00;
			end 
    end
assign busy_o = busy_q;

//clk divider for baud-rate
always @ (posedge clk_i, negedge reset_ni)
    begin: BAUDRATE_GENERATOR
        if(!reset_ni)
            begin
            clk_counter_q <= 16'h0000;
            clk_en_baud_q <= 1'b0;
            end
        else
            begin
			if (busy_q)
				begin
				if (clk_counter_q == 16'h0000)
					clk_en_baud_q <= 1'b1;
				else
					clk_en_baud_q <= 1'b0;
					
				if (clk_counter_q < BAUD_DIVIDER-1)
					clk_counter_q <= clk_counter_q + 1;
				else
					clk_counter_q <= 16'h0000;
				end
			else
				begin
				clk_counter_q <= 16'h0000;
				clk_en_baud_q <= 1'b0;
				end
            end
    end

//uart tx state-machine (register)
always @ (posedge clk_i, negedge reset_ni)
    begin: STATEMACHINE_TX
        if (!reset_ni)
            begin
            tx_state_q <= TX_STATE_IDLE;
            tx_q <= 10'b0000000000;
            tx_output_q <= 1'b1;
            tx_counter_q <= 4'h0;
            end
        else if (clk_en_baud_q) //only advance the statemachine with baud-rate speed
            begin
            tx_state_q <= tx_state_d;
            tx_q <= tx_d;
            tx_output_q <= tx_output_d;
            tx_counter_q <= tx_counter_d;
            end
 end

//uart tx state-machine (combinatoric)
always @ (reset_ni, tx_state_q, busy_q, tx_data_q, tx_q, tx_counter_q)
    begin: STATEMACHINE_TX_COMB
        if (!reset_ni)
            begin
            tx_state_d = TX_STATE_IDLE;
            tx_output_d = 1'b1; //always 1 when idle
            tx_d = 10'b0000000000;
            tx_counter_d = 4'b0000;
            end
        else 
			case(tx_state_q)
                TX_STATE_IDLE: 
					if (busy_q)
                        begin
                        tx_state_d = TX_STATE_TRANSMIT;
                        tx_counter_d = 4'b1010; //11 bits to transmit
                        tx_d = {2'b11, tx_data_q}; // 2 stop bit, tx-data, start bt (back to front)
                        tx_output_d = 1'b0; //send start bit
                        end
                    else
                        begin
                        tx_state_d = TX_STATE_IDLE;
                        tx_output_d = 1'b1; //always 1 when idle
                        tx_counter_d = 4'b0000;
						tx_d = 10'b0000000000;
                        end

				TX_STATE_TRANSMIT:
					if (tx_counter_q != 4'b0000)
						begin
						tx_state_d = TX_STATE_TRANSMIT;
						tx_output_d = tx_q[0];
						tx_d = tx_q >> 1;
						tx_counter_d = tx_counter_q -1;
						end
					else
						begin
						tx_state_d = TX_STATE_IDLE; 
						tx_output_d = 1'b1;
						tx_d = 10'b0000000000;
						tx_counter_d = 4'b0000;
						end
                   
                default:
					begin
					tx_state_d = TX_STATE_IDLE; 
					tx_output_d = 1'b1;
					tx_d = 10'b0000000000;
					tx_counter_d = 4'b0000;
					end
            endcase
 
	end
 assign tx_o = tx_output_q;
 
 
endmodule
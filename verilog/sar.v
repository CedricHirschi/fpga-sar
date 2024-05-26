module sar_adc #(
    parameter RESOLUTION = 12
) (
    input wire clk_i,                 // Clock input
    input wire start_i,               // Start conversion signal
    input wire rst_ni,               // Asynchronous reset
    input wire comp_i,      // Input from external analog comparator
    output wire rdy_o,              // Conversion complete signal
    output wire [RESOLUTION - 1:0] dac_o      // Output to external R-2R ladder DAC
);

    // State definitions
    localparam IDLE = 0;
    localparam CONVERT = 1;
    localparam DONE = 2;

    // Internal signals
    reg [2:0] state_q, state_d; // State registers
    reg [RESOLUTION - 1:0] mask_q, mask_d; // Mask for conversion
    reg [RESOLUTION - 1:0] result_q, result_d; // Result of conversion

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q <= IDLE;
            mask_q <= 1 << (RESOLUTION - 1);
            result_q <= 0;
        end else begin
            state_q <= state_d;
            mask_q <= mask_d;
            result_q <= result_d;
        end
    end

    // SAR Conversion Logic
    always @(*) begin

        case (state_q)
            IDLE: begin
                
                if (start_i) begin
                    state_d = CONVERT;
                    mask_d = 1 << (RESOLUTION - 1);
                    result_d = 0;
                end else begin
                    state_d = IDLE;
                    mask_d = mask_q;
                    result_d = result_q;
                end
                
            end

            CONVERT: begin

                if (comp_i) begin
                    mask_d = mask_q >> 1;
                    result_d = result_q | mask_q;
                end else begin
                    mask_d = mask_q >> 1;
                    result_d = result_q;
                end

                if (mask_d == 0) begin
                    state_d = DONE;
                end else begin
                    state_d = CONVERT;
                end
                
            end
                
            DONE: begin

                state_d = IDLE;
                mask_d = mask_q;
                result_d = result_q;
             
            end

            default: begin
                
                state_d = IDLE;
                mask_d = mask_q;
                result_d = result_q;
                
            end

        endcase
    end

    assign dac_o = result_q | mask_q;
    assign rdy_o = (state_q == DONE);

endmodule

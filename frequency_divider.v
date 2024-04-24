module frequency_divider #(
    parameter CLK_FREQ = 12_000_000,
    parameter OUT_FREQ = 1
) (
    output wire divided_o,

    input wire clk_i,
    input wire rst_ni
);

    reg [25:0] counter_q, counter_d;
    reg out_q, out_d;

    assign divided_o = out_q;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            counter_q <= 0;
        end else begin
            counter_q <= counter_d;
        end
    end

    always @(*) begin
        if (counter_q >= CLK_FREQ / OUT_FREQ) begin
            counter_d = 0;
        end else begin
            counter_d = counter_q + 1;
        end
    end

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            out_q <= 0;
        end else begin
            out_q <= out_d;
        end
    end

    always @(*) begin
        if (counter_q == CLK_FREQ / OUT_FREQ / 2) begin
            out_d = 1;
        end else begin
            if (counter_q == 0) begin
                out_d = 0;
            end else begin
                out_d = out_q;
            end
        end
    end
    
endmodule

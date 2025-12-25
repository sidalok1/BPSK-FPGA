module signal_detector
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14,
    // Powers of 2 preferred
    parameter N = 512,
    parameter real dB_THRESH = -20
)
(
    input wire clk, en, rst,
    input wire new_sample,
    input wire signed [SYMBOL_WIDTH-1:0] sample,
    output reg signal_detected
);

    initial signal_detected = 0;
    
    localparam real thresh = $pow(10, (dB_THRESH/10));
    
    localparam signed [(2*SYMBOL_WIDTH)-1:0] power_one = 1 << (SYMBOL_FRAC * 2);
    localparam signed [(2*SYMBOL_WIDTH)-1:0] power_thresh = $rtoi(thresh * power_one);
    
    wire signed [(2*SYMBOL_WIDTH)-1:0] signal_power;
    
    power_estimator #(
        .SYMBOL_WIDTH(SYMBOL_WIDTH),
        .SYMBOL_FRAC(SYMBOL_FRAC),
        .N(N)
    ) signal_power_estimator (
        .clk(clk),
        .en(en),
        .rst(rst),
        .new_sample(new_sample),
        .sample(sample),
        .average_power(signal_power)
    );

    always @ ( posedge clk ) begin
        if ( rst ) begin
            signal_detected <= 0;
        end else
        if ( en ) begin
            signal_detected <= (signal_power > power_thresh) ? 1 : 0;
        end
    end

endmodule

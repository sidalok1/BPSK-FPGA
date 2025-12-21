`timescale 1ns / 1ps

module channel
#(
    parameter ifreq = 96_000_000,
    parameter splr = 6_000_000
)
(
    input wire clk,
    input wire [7:0] dac_data,
    output reg [11:0] impaired_signal = 0
    );
    
    wire new_sample;
    clockdiv
    #(
        .I_CLK_FRQ(ifreq),
        .FREQUENCY(splr)
    ) sample_rate_generator (
        .rst(0),
        .en(1),
        .i_clk(clk),
        .o_clk(new_sample)
    );
    
    localparam real dac_scale_factor = 3.3 / $itor(8'hFF);
    
    integer seed = 0;
    localparam real maxint = $itor(32'hEF_FF_FF_FF);
//    integer stdev = $rtoi(maxint * 0.0033); // snr -30db
    integer stdev = $rtoi(maxint * 0.0033);    
    function real awgn();
        return $dist_normal(seed, 0, stdev)/maxint;
    endfunction
    real clipping;
    function [11:0] adc(input real spl);
        clipping = spl < 0 ? 0 : spl;
        clipping = clipping > 3.3 ? 3.3 : clipping;
        return $rtoi((clipping / 3.3) * 12'hFFF);
    endfunction
    
    real dac_output = 0;
    
    //  Discrete transfer function numerator coefficients
    real a1 = 0.9438;
    real a2 = 0;
    real a3 = -0.9438;
    //  Discrete transfer function denominator coefficients
//    real b1 = 1;
    real b2 = -0.6427;
    real b3 = -0.3483;
    
    real w1 = 0;
    real w2 = 0;
    
    real x = 0;
    real y = 0;
    always @ ( posedge clk ) if ( new_sample ) begin
        x = ($itor(dac_data) * dac_scale_factor) - 1.65;
        y = (a1 * x) + w1;
        w1 = (a2 * x) + w2 - (b2 * y);
        w2 = (a3 * x) - (b3 * y);
        impaired_signal = adc((y * 1.1) + 1.4 + awgn());
    end
    
endmodule

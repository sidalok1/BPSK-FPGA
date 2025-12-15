`default_nettype none

module AGC
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    //  Width of part of input used to index into reciprocal table
    parameter RECIP_WIDTH   = 12,
    //  PID control values
    parameter real kp = 0.1,
    parameter real ki = 0.0,
    parameter real kd = 0.002
)
(
    input wire                              clk, en, rst,
    input wire                              new_sample,
    input wire signed [SYMBOL_WIDTH-1:0]    in_sample,
    output reg signed [SYMBOL_WIDTH-1:0]    out_sample,
    output wire signal_detected
);
    //  Addressable size of reciprocal table
    localparam RECIP_MAX = (2**RECIP_WIDTH) - 1;
    integer n;
    real x;
    reg [(2*RECIP_WIDTH)-1:0] reciprocals [0:RECIP_MAX];
    reg [(2*RECIP_WIDTH)-1:0] recip, gain;
    
    localparam reg signed [31:0] KP = $rtoi(kp * ($pow(2, 16)));
    localparam reg signed [31:0] KI = $rtoi(ki * ($pow(2, 16)));
    localparam reg signed [31:0] KD = $rtoi(kd * ($pow(2, 16)));
    
    reg signed [31:0] err, sum_err, dif_err,
        new_err, new_sum_err, new_dif_err,
        proportional, integral, derivative;
    
    initial begin
        reciprocals[0] = (2**(SYMBOL_WIDTH*2))-1;
        for ( n = 1; n <= RECIP_MAX; n = n + 1 ) begin
            x = 1.0 / itor(n);
            reciprocals[n] = $rtoi(x);
        end
        err = 0;
        sum_err = 0;
        dif_err = 0;
        new_err = 0;
        new_sum_err = 0;
        new_dif_err = 0;
        proportional = 0;
        integral = 0;
        derivative = 0;
        recip = 0;
        gain = 0;
        out_sample = 0;
    end
    
    reg [RECIP_WIDTH-1:0] input_magnitude = 0;
    wire signed [SYMBOL_WIDTH+(RECIP_WIDTH*2):0] amplifier_out;
    
    localparam min_signal = $rtoi(0.1 * (2**SYMBOL_FRAC));
    assign signal_detected = gain >= reciprocals[min_signal];
    
    PipeMult #(
        .WIDTH_A(SYMBOL_WIDTH),
        .WIDTH_B((RECIP_WIDTH*2)+1),
        .PIPELEN(5)
    ) amplifier (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(in_sample),
        .b({1'b0, gain}), // single bit pad ensures this operand always "appears" positive
        // which further ensures msb of output matches that of operand a
        .r(amplifier_out)
    );
    
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            out_sample <= 0;
            recip <= 0;
            gain <= 0;
            derivative <= 0;
            integral <= 0;
            proportional <= 0;
            new_dif_err <= 0;
            new_sum_err <= 0;
            new_err <= 0;
            dif_err <= 0;
            sum_err <= 0;
            err <= 0;
            input_magnitude <= 0;
        end else
        if ( en ) begin
            recip <= reciprocals[input_magnitude];
            
            new_err <= recip - gain;
            new_dif_err <= new_err - err;
            new_sum_err <= new_err + sum_err;
            
            proportional <= (new_err * KP) >>> 16;
            integral <= (new_sum_err * KI) >>> 16;
            derivative <= (new_dif_err * KD) >>> 16;
            if ( new_sample ) begin
                out_sample <= amplifier_out >>> (SYMBOL_FRAC + RECIP_WIDTH);
                gain <= gain + proportional + integral + derivative;
                input_magnitude <=  (in_sample >= 0) ? 
                    (in_sample[(SYMBOL_WIDTH-1)-:8]) : 
                   -(in_sample[(SYMBOL_WIDTH-1)-:8]) ;
            end
        end
    end
    
endmodule

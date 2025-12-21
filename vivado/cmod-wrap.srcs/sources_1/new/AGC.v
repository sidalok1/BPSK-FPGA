module AGC
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    parameter N = 256,
    //  PID control values
    parameter real kp = 0.1,
    parameter real ki = 0.0,
    parameter real kd = 0.002,
    parameter real TARGET_LEVEL = 1.0
)
(
    input wire                              clk, en, rst,
    input wire                              new_sample,
    input wire signed [SYMBOL_WIDTH-1:0]    in_sample,
    output reg signed [SYMBOL_WIDTH-1:0]    out_sample
);

    localparam signed [SYMBOL_WIDTH-1:0] signal_one = 1 << SYMBOL_FRAC;
    localparam signed [(2*SYMBOL_WIDTH)-1:0] power_one = 1 << (SYMBOL_FRAC * 2),
        target_power = $rtoi( ((TARGET_LEVEL**2)/2) * power_one ); // power of sinusoid with amplitude one

    localparam reg signed [31:0] KP = $rtoi(kp * ($pow(2, 16))) / N;
    localparam reg signed [31:0] KI = $rtoi(ki * ($pow(2, 16))) / N;
    localparam reg signed [31:0] KD = $rtoi(kd * ($pow(2, 16))) / N;
    
    reg signed [31:0] err, sum_err, dif_err,
        new_err, new_sum_err, new_dif_err,
        proportional, integral, derivative;

    localparam GAIN_FRAC = 16;
    reg signed [31:0] gain, newgain;
    wire signed [(SYMBOL_WIDTH+32)-1:0] amplifier_output;
    wire signed [(2*SYMBOL_WIDTH)-1:0] signal_power;
    reg signed [SYMBOL_WIDTH-1:0] amplified_signal, signal;
    
    PipeMult #(
        .WIDTH_A(SYMBOL_WIDTH),
        .WIDTH_B(32),
        .PIPELEN(10)
    ) amplifier (
        .clk(clk),
        .en(en),
        .rst(rst),
        .a(signal),
        .b(gain),
        .r(amplifier_output)
    );
    
    
    power_estimator #(
        .SYMBOL_WIDTH(SYMBOL_WIDTH),
        .SYMBOL_FRAC(SYMBOL_FRAC),
        .N(N)
    ) average_power_estimator (
        .clk(clk),
        .en(en),
        .rst(rst),
        .new_sample(new_sample),
        .sample(amplified_signal),
        .average_power(signal_power)
    );
    
    initial begin
        err = 0;
        sum_err = 0;
        dif_err = 0;
        new_err = 0;
        new_sum_err = 0;
        new_dif_err = 0;
        proportional = 0;
        integral = 0;
        derivative = 0;
        out_sample = 0;
        gain = 0;
        newgain = 0;
        amplified_signal = 0;
        signal = 0;
    end
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            out_sample <= 0;
            derivative <= 0;
            integral <= 0;
            proportional <= 0;
            new_dif_err <= 0;
            new_sum_err <= 0;
            new_err <= 0;
            dif_err <= 0;
            sum_err <= 0;
            err <= 0;
            gain <= 0;
            newgain <= 0;
            amplified_signal <= 0;
            signal <= 0;
        end else
        if ( en ) begin
            amplified_signal <= amplifier_output >>> GAIN_FRAC;
            
            new_err <= target_power - signal_power;
            new_dif_err <= new_err - err;
            new_sum_err <= new_err + sum_err;
            
            proportional <= (new_err * KP) >>> 16;
            integral <= (new_sum_err * KI) >>> 16;
            derivative <= (new_dif_err * KD) >>> 16;
            
            newgain <= gain + proportional + integral + derivative;
            if ( new_sample ) begin
                signal <= in_sample;
                out_sample <= amplified_signal;
                
                err <= new_err;
                dif_err <= new_dif_err;
                sum_err <= new_sum_err;
                
                gain <= newgain > 0 ? newgain : 0;
            end
        end
    end
    
endmodule

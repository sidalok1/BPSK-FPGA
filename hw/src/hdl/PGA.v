module PGA
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    parameter N = 512,
    //  PID control values
    parameter real kp = 0.1,
    parameter real ki = 0.0,
    parameter real kd = 0.002,
    parameter real TARGET = 1.0
)
(
    input wire                              clk, en, rst,
    input wire                              new_sample,
    input wire signed [SYMBOL_WIDTH-1:0]    in_sample,
    output reg signed [SYMBOL_WIDTH-1:0]    out_sample
);

    localparam PID_FRAC = SYMBOL_FRAC;
    localparam PID_WIDTH = PID_FRAC*2;


    localparam reg signed [PID_WIDTH-1:0] KP = $rtoi(kp * (2**PID_FRAC));
    localparam reg signed [PID_WIDTH-1:0] KI = $rtoi(ki * (2**PID_FRAC));
    localparam reg signed [PID_WIDTH-1:0] KD = $rtoi(kd * (2**PID_FRAC));
    
    reg signed [PID_WIDTH-1:0] err, sum_err, dif_err,
        new_err, new_sum_err, new_dif_err,
        proportional, integral, derivative;

    reg signed [PID_WIDTH-1:0] gain, newgain;
    wire signed [(SYMBOL_WIDTH+PID_WIDTH)-1:0] amplifier_output, max_level;
    reg signed [SYMBOL_WIDTH-1:0] amplified_signal;
    localparam signed [(SYMBOL_WIDTH+PID_WIDTH)-1:0] target_level = $rtoi(TARGET * 2**(PID_FRAC+SYMBOL_FRAC));
    
    reg signed [SYMBOL_WIDTH-1:0] max_signal = 0;
    
    PipeMult #(
        .WIDTH_A(SYMBOL_WIDTH),
        .WIDTH_B(PID_WIDTH),
        .PIPELEN(10)
    ) err_amplifier (
        .clk(clk),
        .en(en),
        .rst(rst),
        .a(max_signal),
        .b(gain),
        .r(max_level)
    );
    
    PipeMult #(
        .WIDTH_A(SYMBOL_WIDTH),
        .WIDTH_B(PID_WIDTH),
        .PIPELEN(10)
    ) amplifier (
        .clk(clk),
        .en(en),
        .rst(rst),
        .a(in_sample),
        .b(gain),
        .r(amplifier_output)
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
            max_signal <= 0;
        end else
        if ( en ) begin
            amplified_signal <= amplifier_output >>> PID_FRAC;
            
            new_err <= (target_level >>> SYMBOL_FRAC) - (max_level >>> SYMBOL_FRAC);
            new_dif_err <= new_err - err;
            new_sum_err <= new_err + sum_err;
            
            proportional <= (new_err * KP) >>> PID_FRAC;
            integral <= (new_sum_err * KI) >>> PID_FRAC;
            derivative <= (new_dif_err * KD) >>> PID_FRAC;
            
            newgain <= gain + proportional + integral + derivative;
            if ( new_sample ) begin
                max_signal <= (in_sample > max_signal) ? in_sample : max_signal;
            
                out_sample <= amplified_signal;
                
                err <= new_err;
                dif_err <= new_dif_err;
                sum_err <= new_sum_err;
                
                gain <= newgain;
            end
        end
    end
    
endmodule


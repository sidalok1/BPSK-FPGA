module AGC_old
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    //  Input clock frequency in hertz
    //  PID control values
    parameter kp = 4,
    parameter gkp = -6,
    parameter win = 128
)
(
    input wire                              clk, en, rst,
    input wire                              new_sample,
    input wire signed [SYMBOL_WIDTH-1:0]    in_sample,
    output reg signed [SYMBOL_WIDTH-1:0]    out_sample,
    output wire signal_detected
);

    localparam GAIN_WIDTH = 32;
    localparam GAIN_FRAC = 16;
    localparam GAIN_WHOLE = GAIN_WIDTH - GAIN_FRAC;
    localparam GAIN_ONE = {{GAIN_WHOLE-1{1'b0}}, 1'b1, {GAIN_FRAC{1'b0}}};
    localparam real GAIN_ONE_REAL = $itor(GAIN_ONE);

    localparam SYMBOL_WHOLE     = SYMBOL_WIDTH - SYMBOL_FRAC;
    localparam SYMBOL_ONE       = {{SYMBOL_WHOLE-1{1'b0}}, 1'b1, {SYMBOL_FRAC{1'b0}}};
    localparam real SYMB_ONE_REAL = $itor(SYMBOL_ONE);
    localparam real noise_floor = 0.033; // somewhat arbitrary, not really tied to noise floor
    localparam integer reference = $rtoi(0.5 * SYMB_ONE_REAL);
//    localparam integer reference = $rtoi(0.2 * GAIN_ONE_REAL);
    localparam integer max_gain = $rtoi(SYMBOL_ONE/noise_floor);

    
    integer gain;
    integer target_gain;
    integer count;
    reg signed [SYMBOL_WIDTH-1:0] max_signal;
    assign signal_detected = target_gain < max_gain;


    reg signed [SYMBOL_WIDTH-1:0] in_signal;
    
    reg signed [(2*SYMBOL_WIDTH)-1:0] amplified;
    reg signed [(2*SYMBOL_WIDTH)-1:0] abs;
    integer err, gain_err;
    
    integer newgain1, newgain2, newtarget_gain1, newtarget_gain2;
    
    initial begin
        gain = 0;
        err = 0;
        gain_err = 0;
        out_sample = 0;
        in_signal = 0;
        amplified = 0;
        abs = 0;
        target_gain = 0;
        count = 0;
        max_signal = 0;
        newgain1 = 0;
        newtarget_gain1 = 0;
        newgain2 = 0;
        newtarget_gain2 = 0;
    end
    
    
    always @ ( posedge clk )
    if ( rst ) begin
//        gain <= max_gain;
        max_signal <= 0;
        gain <= 0;
        gain_err <= 0;
        out_sample <= 0;
        in_signal <= 0;
        amplified <= 0;
        abs <= 0;
        err <= 0;
        target_gain <= 0;
        count <= 0;
        newgain1 <= 0;
        newtarget_gain1 <= 0;
        newgain2 <= 0;
        newtarget_gain2 <= 0;
    end else
    if ( en ) begin
        amplified <= (in_signal * gain) >>> GAIN_FRAC;
        abs <= amplified < 0 ? -1*amplified : amplified;
        err <= reference - max_signal;
        gain_err <= target_gain - gain;
        if ( gkp < 0 ) begin
            newgain1 <= gain + (gain_err >>> -gkp);
        end else begin
            newgain1 <= gain + (gain_err <<< gkp);
        end
        if ( kp < 0 ) begin
            newtarget_gain1 <= target_gain + (err >>> -kp);
        end else begin
            newtarget_gain1 <= target_gain + (err <<< kp);
        end
        newgain2 <= newgain1 < 0 ? 0 : newgain1;
        newtarget_gain2 <= newtarget_gain1 < 0 ? 0 : newtarget_gain1;
        if ( new_sample ) begin
            in_signal <= in_sample;
            out_sample <= amplified;
            gain <= newgain2 < max_gain ? newgain2 : max_gain;
            if ( count == win ) begin
                target_gain <= newtarget_gain2 < max_gain ? newtarget_gain2 : max_gain;
                max_signal <= 0;
                count <= 0;
            end else begin
                max_signal <= abs > max_signal ? abs : max_signal;
                count <= count + 1;
            end
        end
    end
    
    
    
endmodule

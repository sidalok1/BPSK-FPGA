module Costas_Loop
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14,
    parameter SAMPLE_RATE = 6_000_000,
    parameter CARRIER_FRQ = 1_000_000,
    parameter kp = 4,
    parameter ki = -2,
    parameter kd = -1
)
(
    input wire clk, rst, en,
    input wire new_sample,
    input wire signed [SYMBOL_WIDTH-1:0] modulated_input,
    output reg signed [SYMBOL_WIDTH-1:0] I_component, Q_component
);
    localparam WDTH = 32;
    localparam FRAC = 16;
    wire signed [WDTH-1:0] input_sample = modulated_input <<< FRAC - SYMBOL_FRAC;
    
//    localparam signed [SYMBOL_WIDTH-1:0] SYMB_MIN = 2**(SYMBOL_WIDTH-1);
//    localparam signed [SYMBOL_WIDTH-1:0] SYMB_MAX = 2**(SYMBOL_WIDTH-1) - 1;
//    localparam signed [WDTH-1:0] MIN = SYMB_MIN <<< FRAC - SYMBOL_FRAC;
//    localparam signed [WDTH-1:0] MAX = SYMB_MAX <<< FRAC - SYMBOL_FRAC;
    
    localparam signed [WDTH-1:0] KP = $rtoi(kp * ($pow(2, $itor(FRAC))));
    localparam signed [WDTH-1:0] KI = $rtoi(ki * ($pow(2, $itor(FRAC))));
    localparam signed [WDTH-1:0] KD = $rtoi(kd * ($pow(2, $itor(FRAC))));
    
    wire signed [WDTH-1:0] cosine, neg_sine;
    
    localparam phase_resolution = FRAC;
    wire [phase_resolution-1:0] _theta;
    reg signed [WDTH-1:0] theta;
    assign _theta = (theta + 16'h8000) >> (FRAC - phase_resolution);
//    assign _theta = theta;
    
    IQGenerator #(
        .SYMBOL_WIDTH(WDTH),
        .SYMBOL_FRAC(FRAC),
        .SAMPLE_RATE(SAMPLE_RATE),
        .FREQUENCY(CARRIER_FRQ),
        .RES(phase_resolution)
    ) carrier_generator (
        .clk(clk),
        .rst(rst),
        .en(en),
        .new_sample(new_sample),
        .offset(_theta),
        .I(cosine),
        .Q(neg_sine)
    );
    
    wire signed [(2*WDTH)-1:0] cos_mult_out, sin_mult_out;
    reg signed [WDTH-1:0] cos_mixed_signal, sin_mixed_signal;
    
    PipeMult #(
        .WIDTH_A(WDTH),
        .WIDTH_B(WDTH),
        .PIPELEN(3)
    ) in_phase_mixer (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(input_sample),
        .b(cosine),
        .r(cos_mult_out)
    );
    
    PipeMult #(
        .WIDTH_A(WDTH),
        .WIDTH_B(WDTH),
        .PIPELEN(3)
    ) quadrature_mixer (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(input_sample),
        .b(neg_sine),
        .r(sin_mult_out)
    );
    
    
    wire signed [WDTH-1:0] in_phase, quadrature;
    
    FIR #(
        .SYMBOL_WIDTH(WDTH),
        .SYMBOL_FRAC(FRAC),
        .FILT_TAPS(8),
        .memfile("costas_lp.mem")
    ) in_phase_filter (
        .clk(clk),
        .rst(rst),
        .en(en),
        .new_sample(new_sample),
        .i_sample(cos_mixed_signal),
        .o_sample(in_phase)
    );
    
    FIR #(
        .SYMBOL_WIDTH(WDTH),
        .SYMBOL_FRAC(FRAC),
        .FILT_TAPS(8),
        .memfile("costas_lp.mem")
    ) quadrature_filter (
        .clk(clk),
        .rst(rst),
        .en(en),
        .new_sample(new_sample),
        .i_sample(sin_mixed_signal),
        .o_sample(quadrature)
    );
    
    wire signed [(2*WDTH)-1:0] err_mult_out;
    
    PipeMult #(
        .WIDTH_A(WDTH),
        .WIDTH_B(WDTH),
        .PIPELEN(2)
    ) error_mult_pipeline (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(in_phase),
        .b(quadrature),
        .r(err_mult_out)
    );
    
    reg signed [WDTH-1:0] err, sum_err, dif_err, old_err, 
        proportional, integral, derivative, 
        newtheta1, newtheta2, newtheta3;
    
    initial begin
        err = 0;
        sum_err = 0;
        dif_err = 0;
        old_err = 0;
        proportional = 0;
        integral = 0;
        derivative = 0;
        newtheta1 = 0;
        newtheta2 = 0;
        newtheta3 = 0;
        cos_mixed_signal = 0;
        sin_mixed_signal = 0;
        theta = 0;
        I_component = 0;
        Q_component = 0;
    end
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            err <= 0;
            sum_err <= 0;
            dif_err <= 0;
            old_err <= 0;
            proportional <= 0;
            integral <= 0;
            derivative <= 0;
            newtheta1 <= 0;
            newtheta2 <= 0;
            newtheta3 <= 0;
            cos_mixed_signal <= 0;
            sin_mixed_signal <= 0;
            theta <= 0;
            I_component <= 0;
            Q_component <= 0;
        end else
        if ( en ) begin
            cos_mixed_signal <= cos_mult_out >>> FRAC;
            sin_mixed_signal <= sin_mult_out >>> FRAC;
            err <= err_mult_out >>> FRAC;

            proportional <= ( err * KP ) >>> FRAC;
            integral <= ( sum_err * KI ) >>> FRAC;
            derivative <= ( dif_err * KD ) >>> FRAC;
                
            newtheta1 <= theta + proportional;
            newtheta2 <= newtheta1 + integral;
            newtheta3 <= newtheta2 + derivative;
            
            if ( new_sample ) begin
                I_component <= in_phase >>> (FRAC - SYMBOL_FRAC);
                
                theta <= newtheta3;
                old_err <= err;
                sum_err <= sum_err + err;
                dif_err <= err - old_err;
            end
        end
    end
    
    
endmodule

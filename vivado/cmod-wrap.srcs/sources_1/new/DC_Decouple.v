module DC_Decouple
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14,
    parameter window = 64,
    parameter real kp = 0.1,
    parameter real ki = 0.0002,
    parameter real kd = 0.01
)
(
    input wire clk, rst, en,
    input wire new_sample,
    input wire signed [SYMBOL_WIDTH-1:0] sample,
    output reg signed [SYMBOL_WIDTH-1:0] ac_signal
);

    initial ac_signal = 0;

    localparam LOG_WINDOW = $clog2(window);

    localparam CNT_WIDTH = LOG_WINDOW;
    reg [CNT_WIDTH-1:0] counter = 0;

    localparam ACC_WIDTH = LOG_WINDOW + SYMBOL_WIDTH;
    reg signed [ACC_WIDTH-1:0] accumulator = 0;
    
    reg signed [SYMBOL_WIDTH-1:0] average = 0, offset = 0, 
        new_err = 0, new_dif = 0, new_sum = 0,
        err = 0, sum_err = 0, dif_err = 0,
        proportional = 0, integral = 0, derivative = 0, delta = 0;
    
    localparam SYMBOL_WHOLE     = SYMBOL_WIDTH - SYMBOL_FRAC;
    localparam SYMBOL_ONE       = {{SYMBOL_WHOLE-1{1'b0}}, 1'b1, {SYMBOL_FRAC{1'b0}}};
    
    localparam reg signed [SYMBOL_WIDTH-1:0] KP = $rtoi(kp * SYMBOL_ONE);
    localparam reg signed [SYMBOL_WIDTH-1:0] KI = $rtoi(ki * SYMBOL_ONE);
    localparam reg signed [SYMBOL_WIDTH-1:0] KD = $rtoi(kd * SYMBOL_ONE);


    always @ ( posedge clk ) begin
    if ( rst ) begin
        ac_signal <= 0;
        counter <= 0;
        accumulator <= 0;
        average <= 0;
        offset <= 0;
        new_err <= 0;
        new_dif <= 0;
        new_sum <= 0;
        err <= 0;
        sum_err <= 0;
        dif_err <= 0;
        proportional <= 0;
        integral <= 0;
        derivative <= 0;
        delta <= 0;
    end else
    if ( en ) begin
        
        new_err <= average - offset;
        new_sum <= new_err + sum_err;
        new_dif <= new_err - err;
        
//        proportional <= ( new_err * KP ) >>> SYMBOL_FRAC;
//        integral <= ( new_sum * KI ) >>> SYMBOL_FRAC;
//        derivative <= ( new_dif * KD ) >>> SYMBOL_FRAC;
        
//        delta <= proportional + integral + derivative;
        delta <= new_err >>> 2;        
        if ( new_sample ) begin
            ac_signal <= sample - offset;
                     
            offset <= offset + delta;
            err <= new_err;
            sum_err <= new_sum;
            dif_err <= new_dif;
        
            if ( counter == window - 1 ) begin
                average <= accumulator >>> LOG_WINDOW; // equivalent to dividing by window
                accumulator <= sample;
                counter <= 0;
            end else begin
                accumulator <= accumulator + sample;
                counter <= counter + 1;
            end
        end
    end
    end


endmodule

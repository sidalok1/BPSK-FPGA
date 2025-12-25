module Early_Late_TED
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14,
    parameter SPS = 120,
    parameter real kp = 0.1,
    parameter real ki = 0.0002,
    parameter real kd = 0
)
(
    input wire clk, rst, en,
    input wire new_sample,
    input wire signed [SYMBOL_WIDTH-1:0] sample,
    output reg symbol_ready,
    output reg signed [SYMBOL_WIDTH-1:0] symbol
    );
    
    // SPS_guess must be no less than half true SPS
    localparam ctr_w = $clog2(SPS) + 2;
    
    reg signed [ctr_w-1:0] counter;
    reg signed [ctr_w-1:0] tau;
    
    reg signed [31:0] err, sum_err, dif_err, new_err, new_dif_err, new_sum_err,
        proportional, integral, derivative, pos_err, neg_err,
        delta_tau;
    
    localparam reg signed [31:0] KP = $rtoi(kp * ($pow(2, 16)));
    localparam reg signed [31:0] KI = $rtoi(ki * ($pow(2, 16)));
    localparam reg signed [31:0] KD = $rtoi(kd * ($pow(2, 16)));
    
    reg signed [SYMBOL_WIDTH-1:0] early, prompt, late;
    
    //  The maximum error of one corresponds to being halfway between symbols
    localparam max_sps_change = SPS / 2;
    
    always @ ( posedge clk ) begin
    if ( rst ) begin
        symbol_ready <= 0;
        symbol <= 0;
        counter <= 0;
        tau <= 0;
        err <= 0;
        sum_err <= 0;
        dif_err <= 0;
        
        new_err <= 0;
        new_dif_err <= 0;
        new_sum_err <= 0;
        
        proportional <= 0;
        integral <= 0;
        derivative <= 0;
        
        pos_err <= 0;
        neg_err <= 0;
        delta_tau <= 0;
        
        early <= 0;
        prompt <= 0;
        late <= 0;
    end else 
    if ( en ) begin
        symbol_ready <= 0;
        pos_err <= (early - late) <<< (16 - SYMBOL_FRAC);
        neg_err <= (late - early) <<< (16 - SYMBOL_FRAC);
        new_err <= (prompt <= 0) ? pos_err : neg_err;
        
        new_dif_err <= new_err - err;
        new_sum_err <= new_err + sum_err;
        
        proportional <= (new_err * KP) >>> 16;
        integral <= (new_sum_err * KI) >>> 16;
        derivative <= (new_dif_err * KD) >>> 16;
        
        delta_tau <= (proportional + integral + derivative) * max_sps_change;
        
        if ( new_sample ) begin
            counter <= counter + 1;
        
            if ( counter == (SPS + tau) - 2) begin
                early <= sample;
            end else
            if ( counter == (SPS + tau) - 1) begin
                prompt <= sample;
                symbol <= sample;
                symbol_ready <= 1;
                counter <= 0;              
            end else
            if ( counter == 0 ) begin
                late <= sample;
            end else
            if ( counter == 1 ) begin
                err <= new_err;    
                sum_err <= new_sum_err;
                dif_err <= new_dif_err;
                tau <= tau + (delta_tau >>> 16); // update tau by whole number  
            end
        end
    end
    end
    
    initial begin
        symbol_ready = 0;
        symbol = 0;
        counter = 0;
        tau = 0;
        
        err = 0;
        sum_err = 0;
        dif_err = 0;
        
        new_err = 0;
        new_sum_err = 0;
        new_dif_err = 0;
        
        proportional = 0;
        integral = 0;
        derivative = 0;
        
        pos_err = 0;
        neg_err = 0;
        delta_tau = 0;
        
        early = 0;
        prompt = 0;
        late = 0;
    end
    
endmodule

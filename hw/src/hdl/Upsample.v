module Upsample
#(
    //  Output sample rate in hertz
    parameter OUT_RATE   = 6_000_000,
    // Output rate of ADC
    parameter IN_RATE = 3_000_000,
    parameter SYMBOL_WIDTH = 16
)
(
    input wire                      clk, rst, en,
    input wire                      new_sample,
    input wire [SYMBOL_WIDTH-1:0]   i_sample,
    output reg [SYMBOL_WIDTH-1:0]   o_sample
);

    localparam UPSAMPLE_FACTOR = OUT_RATE / IN_RATE;
    localparam ADDED_SAMPLES = UPSAMPLE_FACTOR - 1;
    
    integer count;
    
    
    initial begin
        count = 0;
        o_sample = 0;
    end
    
    always @ ( posedge clk )
    if ( rst ) begin
        o_sample <= 0;
        count <= 0;
    end else
    if ( en ) begin
        if ( new_sample ) begin
            if ( count == ADDED_SAMPLES ) begin
                count <= 0;
                o_sample <= i_sample;
            end else begin
                count <= count + 1;
                o_sample <= 0;
            end
        end
    end
endmodule

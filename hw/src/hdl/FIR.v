module FIR
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    
    //  Following two parameters MUST be defined at instantiation
    
    //  Number of taps in the filter
    parameter FILT_TAPS    = 0,
    //  Name of the memory file for readmemh directive
    parameter memfile       = ""
)
(
    input wire                              clk,
    input wire                              rst,
    input wire                              en,
    input wire                              new_sample,
    
    input wire signed [SYMBOL_WIDTH-1:0]    i_sample,
    
    output reg signed [SYMBOL_WIDTH-1:0]    o_sample
);

    reg signed [SYMBOL_WIDTH-1:0] taps [0:FILT_TAPS-1];
    reg signed [(SYMBOL_WIDTH*2)-1:0] muls [0:FILT_TAPS-1];
    reg signed [SYMBOL_WIDTH-1:0] input_sample;
    //  Calculated bitlength of the symbol representing the nonfractional number
    localparam SYMBOL_WHOLE     = SYMBOL_WIDTH - SYMBOL_FRAC;
    //  Two's complement symbols parameterized to given bitwidths
    localparam SYMBOL_ZERO      = {SYMBOL_WIDTH{1'b0}};
    
    //  Non-synthesized indexing variables
    integer i;
    
    reg signed [(SYMBOL_WIDTH*2)-1:0] accs [0:FILT_TAPS-1];
    
    localparam [1:0] IDLE   = 'b01;
    localparam [1:0] CALC   = 'b10;
    reg [1:0] state = IDLE;
    
    
    initial begin
        input_sample = 0;
        o_sample = SYMBOL_ZERO;
        $readmemb(memfile, taps);
        for ( i = 0; i < FILT_TAPS; i = i + 1 ) begin
            muls[i] = 0;
            accs[i] = 0;
        end
    end
    
    always @ ( posedge clk )
    if ( rst ) begin
        input_sample <= 0;
        o_sample <= SYMBOL_ZERO;
        for ( i = 0; i < FILT_TAPS; i = i + 1 ) begin
            accs[i] <= 0;
            muls[i] <= 0;
        end
    end else
    if ( en ) begin
        if ( new_sample ) begin
            input_sample <= i_sample;
            for ( i = 0; i < FILT_TAPS; i = i + 1 ) begin
                muls[i] <= taps[i] * input_sample;
            end
            accs[FILT_TAPS-1] <= muls[FILT_TAPS-1];
            for ( i = 0; i < FILT_TAPS - 1; i = i + 1 ) begin
                accs[i] <= muls[i] + accs[i+1];
            end
            o_sample <= accs[0] >>> (SYMBOL_FRAC - 2); // fixed x4 gain
        end
    end
    
    
    
endmodule

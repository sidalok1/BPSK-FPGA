`default_nettype none

module RootRaisedCosFilter
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    //  Input clock frequency in hertz
    parameter CLOCK_FREQ    = 96_000_000,
    //  Output sample rate in hertz
    parameter SAMPLE_RATE   = 6_000_000,
    //  Symbol rate in hertz, together with last value determin sps
    parameter SYMBOL_RATE   = 50_000,
    //  How many symbols the filter spans
    parameter SPAN          = 3,
    // Name of the memory file for readmemh directive
    parameter memfile       = "psfilt.mem"
)
(
    input wire                              clk,
    input wire                              rst,
    input wire                              en,
    // High when there is a new sample ready at the input
//    input wire                              i_dready,
    input wire signed [SYMBOL_WIDTH-1:0]    i_sample,
    
//    output reg                              o_dready,
    output reg signed [SYMBOL_WIDTH-1:0]    o_sample
);

    //  Symbols per sample
    localparam integer SPS      = SAMPLE_RATE / SYMBOL_RATE;
    localparam FILT_WIDTH       = SPS * SPAN;
    
    wire new_sample;
    clockdiv
    #(
        .I_CLK_FRQ(CLOCK_FREQ),
        .FREQUENCY(SAMPLE_RATE)
    ) sample_rate_generator (
        .rst(rst),
        .en(en),
        .i_clk(clk),
        .o_clk(new_sample)
    );
    
    //  Number of cycles before next input is ready
    localparam N    = CLOCK_FREQ / SAMPLE_RATE;
    //  Number of accumulators so that calculations can be done in time
    localparam MULS = FILT_WIDTH / N;
    localparam SUMS    = MULS / 2;
    
    //  Synthesized indexing variables
    integer idx = 0, jdx = 0;
    //  Non-synthesized indexing variables
    integer i, j, k;
    
    reg signed [(SYMBOL_WIDTH*2)-1:0] mults [0:MULS-1];
    reg signed [(SYMBOL_WIDTH*2)-1:0] sums [0:SUMS-1];
    reg signed [(SYMBOL_WIDTH*2)-1:0] total;
    
    reg signed [SYMBOL_WIDTH-1:0] taps [0:FILT_WIDTH-1];
    reg signed [SYMBOL_WIDTH-1:0] ins [0:FILT_WIDTH-1];

    //  Calculated bitlength of the symbol representing the nonfractional number
    localparam SYMBOL_WHOLE     = SYMBOL_WIDTH - SYMBOL_FRAC;
    //  Two's complement symbols parameterized to given bitwidths
    localparam SYMBOL_ZERO      = {SYMBOL_WIDTH{1'b0}};
    
    initial begin
        o_sample = SYMBOL_ZERO;
//        o_dready = 0;
        total = 0;
        $readmemb(memfile, taps);
        for ( i = 0; i < FILT_WIDTH; i = i + 1 ) begin
            ins[i] = 0;
        end
        for ( j = 0; j < MULS; j = j + 1 ) begin
            mults[j] = 0;
        end
        for ( k = 0; k < SUMS; k = k + 1 ) begin
            sums[k] = 0;
        end
    end
    
    localparam IDLE = 0;
    localparam CALC = 1;
    reg state = IDLE;
    reg mul_ready = 0;
    
    localparam fixed_gain = 4;
    
    always @ ( posedge clk )
    if ( rst ) begin
        state <= IDLE;
        mul_ready <= 0;
        o_sample <= SYMBOL_ZERO;
        total <= 0;
        for ( i = 0; i < FILT_WIDTH; i = i + 1 ) begin
            ins[i] <= 0;
        end
        for ( j = 0; j < MULS; j = j + 1 ) begin
            mults[j] <= 0;
        end
        for ( k = 0; k < SUMS; k = k + 1 ) begin
            sums[k] <= 0;
        end
        idx <= 0;
        jdx <= 0;
    end else
    if ( en ) begin
        mul_ready <= 0;
        
        if ( idx == 0 ) begin
            for ( j = 0; j < MULS; j = j + 1 ) begin
                mults[j] <= (ins[(N*j)+idx] * taps[(N*j)+idx]);
            end
        end else begin
            for ( j = 0; j < MULS; j = j + 1 ) begin
                mults[j] <= mults[j] + (ins[(N*j)+idx] * taps[(N*j)+idx]);
            end
        end
        
        if ( idx == N - 1 ) begin
            mul_ready <= 1;
            idx <= 0;
            ins[0] <= i_sample;
            for ( i = 1; i < FILT_WIDTH; i = i + 1 ) begin
                ins[i] <= ins[i-1];
            end
        end else begin
            idx <= idx + 1;
        end
        
        case ( state )
        IDLE: begin
            if ( mul_ready ) begin
                for ( k = 0; k < SUMS; k = k + 1 ) begin
                    sums[k] <= mults[(2*k)] + mults[(2*k)+1];
                end
                jdx <= 0;
                total <= 0;
                state <= CALC;
            end
        end
        CALC: begin
            if ( jdx == SUMS ) begin
                o_sample <= total >>> SYMBOL_FRAC;
                state <= IDLE;
            end else begin
                total <= total + (sums[jdx] * fixed_gain);
                jdx <= jdx + 1;
            end
        end
        endcase
        
        
    end

endmodule

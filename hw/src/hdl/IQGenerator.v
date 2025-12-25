module IQGenerator
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    //  Output sample rate in hertz
    parameter SAMPLE_RATE   = 6_000_000,
    //  Output frequency
    parameter FREQUENCY     = 1_000_000,
    //  Bit resolution of phase
    parameter RES           = 8
)
(
    input wire                              clk,
    input wire                              rst,
    input wire                              en,
    input wire                              new_sample,
    //  Phase offset
    input wire [RES-1:0]                    offset,
    //  In phase sinusoid
    output reg signed [SYMBOL_WIDTH-1:0]    I,
    //  Quadrature sinusoid
    output reg signed [SYMBOL_WIDTH-1:0]    Q
);

    localparam MAX_PHASE = $rtoi($pow(2, $itor(RES))) - 1;
    
    localparam QMAX_ADDR = $rtoi($pow(2, $itor(RES-2))) - 1;
    reg signed [SYMBOL_WIDTH-1:0] qwave_mem [0:QMAX_ADDR];
    
    integer n;
    real t, pi;
    localparam norm_factor = $pow(2, $itor(SYMBOL_FRAC));
    initial begin
        I = 0;
        Q = 0;
        
        pi = 2 * $asin(1);
        
        for ( n = 0; n <= QMAX_ADDR; n = n + 1 ) begin
            t = $itor(n) * ((pi / 2) / $itor(QMAX_ADDR));
            qwave_mem[n] = $rtoi($cos(t) * norm_factor);
        end
        
    end

    localparam tuning_word = $rtoi($itor(MAX_PHASE) * ($itor(FREQUENCY) / $itor(SAMPLE_RATE)));

    reg [RES-1:0] phase = 0;
    reg [RES-1:0] freq = 0;

    reg [RES-3:0] qphase = 0;
    
    reg [1:0] quarter = 0, quarter_pipe = 0;
    
    reg [SYMBOL_WIDTH-1:0] _I = 0, _Q = 0;
    
    always @ ( posedge clk )
    if ( rst ) begin
        I <= 0;
        Q <= 0;
        phase <= 0;
        freq <= 0;
        qphase <= 0;
        quarter <= 0;
        quarter_pipe <= 0;
        _I <= 0;
        _Q <= 0;
    end else
    if ( en ) begin
        {quarter, qphase} <= phase;
        
        case ( quarter )
        2'd0, 2'd2: begin
            _I <= qwave_mem[qphase];
            _Q <= qwave_mem[QMAX_ADDR - qphase];
        end
        2'd1, 2'd3: begin
            _I <= qwave_mem[QMAX_ADDR - qphase];
            _Q <= qwave_mem[qphase];
        end
        endcase
        quarter_pipe <= quarter;
        
        case ( quarter_pipe )
        2'd0: begin
            I <= _I;
            Q <= _Q * -1;
        end
        2'd1: begin
            I <= _I * -1;
            Q <= _Q * -1;
        end
        2'd2: begin
            I <= _I * -1;
            Q <= _Q;
        end
        2'd3: begin
            I <= _I;
            Q <= _Q;
        end
        endcase
        
        if ( new_sample ) begin
            freq <= freq + tuning_word;
            phase <= freq + offset;
        end
    end

endmodule

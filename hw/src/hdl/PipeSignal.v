module PipeSignal
#( 
    parameter DWIDTH = 16,
    parameter PIPELEN = 0
)
(
    input wire clk, rst, en,
    input wire [DWIDTH-1:0] i,
    output wire [DWIDTH-1:0] o
);

    reg [DWIDTH-1:0] p [0:PIPELEN-1];
    integer idx;
    assign o = p[PIPELEN-1];
    initial for ( idx = 0; idx < PIPELEN; idx = idx + 1) p[idx] = 0;
    
    always @ ( posedge clk ) begin
    if ( rst ) begin
        for ( idx = 0; idx < PIPELEN; idx = idx + 1) p[idx] <= 0;
    end else
    if ( en ) begin
        p[0] <= i;
        for ( idx = 0; idx < PIPELEN-1; idx = idx + 1 ) 
            p[idx+1] <= p[idx];
    end
    end

endmodule


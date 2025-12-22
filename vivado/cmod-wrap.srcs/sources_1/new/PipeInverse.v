module PipeInverse
#(
    //  Assumption is that FRAC == WHOLE == WIDTH/2
    parameter WIDTH = 16,
    parameter PIPELEN = 10
)
(
    input wire clk, rst, en,
    input wire signed [WIDTH-1:0] a,
    output wire signed [WIDTH-1:0] r
);

    localparam signed [(WIDTH*2)-1:0] ONE = 2**(WIDTH);
    localparam signed [WIDTH-1:0] MAX = 2**(WIDTH-1) - 1; // two's complement max

    reg signed [WIDTH-1:0] p [0:PIPELEN-1];
    assign r = p[PIPELEN-1];
    integer i;
    initial begin
        for ( i = 0; i < PIPELEN; i = i + 1 ) begin
            p[i] = 0;
        end
    end
    always @ ( posedge clk ) begin
        if ( rst ) begin
            for ( i = 0; i < PIPELEN; i = i + 1) begin
                p[i] <= 0;
            end
        end else
        if ( en ) begin
        
            p[0] <= ( a == 0 ) ? MAX : ONE / a;
            
            for ( i = 0; i < PIPELEN - 1; i = i + 1) begin
                p[i+1] <= p[i];
            end
        end
    end

endmodule
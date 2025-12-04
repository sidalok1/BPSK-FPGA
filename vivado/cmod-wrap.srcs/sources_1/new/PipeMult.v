module PipeMult
#(
    parameter WIDTH_A = 16,
    parameter WIDTH_B = 16,
    parameter PIPELEN = 2
)
(
    input wire clk, rst, en,
    input wire signed [WIDTH_A-1:0] a,
    input wire signed [WIDTH_B-1:0] b,
    output wire signed [(WIDTH_A+WIDTH_B)-1:0] r
);

    reg signed [(WIDTH_A+WIDTH_B)-1:0] p [0:PIPELEN-1];
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
            p[0] <= a * b;
            for ( i = 0; i < PIPELEN - 1; i = i + 1) begin
                p[i+1] <= p[i];
            end
        end
    end

endmodule

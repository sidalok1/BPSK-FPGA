module power_estimator
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14,
    // Powers of 2 preferred
    parameter N = 512
)
(
    input wire clk, en, rst,
    input wire new_sample,
    input wire signed [SYMBOL_WIDTH-1:0] sample,
    output reg new_estimate,
    output reg signed [(2*SYMBOL_WIDTH)-1:0] average_power
);
    
    localparam logN = $clog2(N);
    reg [logN-1:0] counter;
    reg signed [logN+(2*SYMBOL_WIDTH)-1:0] accumulator;
    reg signed [SYMBOL_WIDTH-1:0] signal;
    wire signed [(2*SYMBOL_WIDTH)-1:0] instantaneous_power;

    PipeMult #(
        .WIDTH_A(SYMBOL_WIDTH),
        .WIDTH_B(SYMBOL_WIDTH),
        .PIPELEN(10)
    ) multiplier (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(signal),
        .b(signal),
        .r(instantaneous_power)
    );

    initial begin
        new_estimate = 0;
        average_power = 0;
        counter = 0;
        accumulator = 0;
        signal = 0;
    end

    always @ ( posedge clk ) begin
        if ( rst ) begin
            new_estimate <= 0;
            average_power <= 0;
            counter <= 0;
            accumulator <= 0;
            signal <= 0;
        end else
        if ( en ) begin
            new_estimate <= 0;
            if ( new_sample ) begin
                signal <= sample;
                if ( counter == N-1 ) begin
                    counter <= 0;
                    new_estimate <= 1;
                    average_power <= accumulator >>> logN; // divide by N, if N is power of two
                    accumulator <= instantaneous_power;
                end else begin
                    counter <= counter + 1;
                    accumulator <= accumulator + instantaneous_power;
                end
            end
        end
    end

endmodule

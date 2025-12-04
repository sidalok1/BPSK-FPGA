module Symbol_Bit_Mapper
#(
    parameter SYMBOL_WIDTH = 16,
    parameter SYMBOL_FRAC = 14
)
(
    input wire clk, rst, en,
    input wire signed [SYMBOL_WIDTH-1:0] symbol,
    input wire new_symbol,
    output reg rx_bit,
    output reg new_bit
);

    initial begin
        rx_bit = 0;
        new_bit = 0;
    end
    
    always @ ( posedge clk ) begin
    if ( rst ) begin
        rx_bit <= 0;
        new_bit <= 0;
    end else
    if ( en ) begin
        if ( new_symbol ) begin
            rx_bit <= (symbol > 0) ? 1'b1 : 1'b0;
            new_bit <= 1;
        end else begin
            rx_bit <= rx_bit;
            new_bit <= 0;
        end
    end
    end

endmodule

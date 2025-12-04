`timescale 1ns / 1ps
`define HALF_PERIOD 5
module tb();

    parameter symb_width = 14;
    parameter symb_frac = 12;
    parameter clk_freq = 96_000_000;
    parameter spl_rate = 48_000_000;
    parameter carrier_frq = 240_000;
    parameter baud_rate = 50_000;
    parameter sync_len = 32;
    
    reg clk;
    always #`HALF_PERIOD clk = (clk === 1'b0);
    wire en = 1;
    wire rst = 0;
    reg start = 0;
    wire signed [symb_width-1:0] I, Q;
//    wire sym_gen_ready;
    
    wire new_sample;
    clockdiv
    #(
        .I_CLK_FRQ(clk_freq),
        .FREQUENCY(spl_rate)
    ) sample_rate_generator (
        .rst(0),
        .en(en),
        .i_clk(clk),
        .o_clk(new_sample)
    );
    
    IQGenerator #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .SAMPLE_RATE(spl_rate),
        .FREQUENCY(carrier_frq),
        .RES(8)
    ) carrier (
        .clk(clk),
        .rst(rst),
        .en(en),
        .new_sample(new_sample),
        .offset(0),
        .I(I),
        .Q(Q)
    );
    
endmodule

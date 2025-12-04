`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2025 12:27:11 AM
// Design Name: 
// Module Name: cmod
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cmod(
    input wire sysclk,
    output wire [7:0] dac,
    output wire cs,
    output wire sclk,
    input wire sdo,
    output wire [1:0] led,
    output wire uart_rxd_out
    );
    
    parameter symb_width = 14;
    parameter symb_frac = 12;
    parameter clk_freq = 96_000_000;
    parameter spl_rate = 6_000_000;
    parameter carrier_frq = 1_000_000;
    parameter baud_rate = 50_000;
    parameter sync_len = 32;
    
    wire en, clk;
    
    clk_gen clk_gen (
        // Clock out ports
        .clk_out1(clk),     // output clk_out1
        // Status and control signals
        .locked(en),       // output locked
        // Clock in ports
        .clk_in1(sysclk)      // input clk_in1
    );
    
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
    
    wire signed [symb_width-1:0] symbol_generator_out;
    
    wire rx_bit, new_bit, msg_found, inv_msg_found;
    
    wire msg_edge;
    
    edgedetect 
        msg_edge_detector (
            .clk(clk),
            .rst(0),
            .sig(msg_found | inv_msg_found),
            .en(msg_edge)
        );
    
    pulse_generator #( .pulse_width(100_000_000) )
        msg_pulse_generator (
            .clk(clk),
            .rst(0),
            .start(msg_edge),
            .sig(led[0])
        );
        
    wire start_tx;
    clockdiv #(
        .I_CLK_FRQ(clk_freq),
        .FREQUENCY(1)
    ) tx_start_clk (
        .rst(0),
        .en(en),
        .i_clk(clk),
        .o_clk(start_tx)
    );
    
    Controller #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .SAMPLE_RATE(spl_rate),
        .SYMBOL_RATE(baud_rate),
        .SYNC_LEN(sync_len)
    ) SYMBGEN (
        .clk(clk),
        .en(en),
        .rst(0),
        .start(start_tx),
        .new_sample(new_sample),
        .sample(symbol_generator_out),
        
        .rx_bit(rx_bit),
        .new_bit(new_bit),
        .msg_found(msg_found),
        .inv_msg_found(inv_msg_found),
        .uart_tx(uart_rxd_out)
    );
    
    wire signed [symb_width-1:0] pulse_shape_out;


    RRC_Filter #(
        .DWIDTH(symb_width),
        .DFRAC(symb_frac),
        .PIPELEN(3)
    ) psfilter (
        .clk(clk),
        .rst(0),
        .in_sample(symbol_generator_out),
        .out_sample(pulse_shape_out)
    );
    
    wire signed [symb_width-1:0] I, Q;
    
    IQGenerator #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .SAMPLE_RATE(spl_rate),
        .FREQUENCY(carrier_frq),
        .RES(8)
    ) carrier_wave_generator (
        .clk(clk),
        .rst(0),
        .en(en),
        .new_sample(new_sample),
        .offset(0),
        .I(I),
        .Q(Q)
    );
    
    wire signed [(2*symb_width)-1:0] modulation_product;
    
    PipeMult #(
        .WIDTH_A(symb_width),
        .WIDTH_B(symb_width),
        .PIPELEN(3)
    ) modulation_mult_pipeline (
        .clk(clk),
        .en(en),
        .rst(0),
        .a(I),
        .b(pulse_shape_out),
        .r(modulation_product)
    );
    
    reg signed [symb_width-1:0] mod_out = 0;
    reg [symb_width-1:0] offset = 0;
    assign dac = offset[symb_width-1:symb_width-8];
    
    localparam symb_whole       = symb_width - symb_frac;
    //  Two's complement symbols parameterized to given bitwidths
    localparam symb_zero        = {symb_width{1'b0}};
    localparam symb_one         = {{symb_whole-1{1'b0}}, 1'b1, {symb_frac{1'b0}}};
    localparam symb_neg_one     = {{symb_whole{1'b1}}, {symb_frac{1'b0}}};
    localparam symb_half        = symb_one / 2;
    
    
    
    //  Receiver code
    
    
    wire [11:0] adc_out;
    
    parameter adc_spl_rate = 3_000_000;
    
    
    MAX11108_Controller adc_controller (
        .clk(clk),
        .rst(0),
        .en(1),
        ._CS(cs),
        .POCI(sdo),
        .SCLK(sclk),
        .data(adc_out)
    );
    
    wire [13:0] adc_increased_bits = {2'b0, adc_out};
    reg signed [13:0] adc_offset = 0;
    wire signed [13:0] upsampled_out;
    
    Upsample #(
        .OUT_RATE(spl_rate),
        .IN_RATE(adc_spl_rate),
        .SYMBOL_WIDTH(symb_width)
    ) adc_samplerate_converter (
        .clk(clk),
        .en(1),
        .rst(0),
        .new_sample(new_sample),
        .i_sample(adc_offset),
        .o_sample(upsampled_out)
    );
    
    wire signed [13:0] filtered_adc;
    FIR #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .FILT_TAPS(12),
        .memfile("upsample_lp.mem")
    ) ADC_filter (
        .clk(clk),
        .en(1),
        .rst(0),
        .new_sample(new_sample),
        .i_sample(upsampled_out),
        .o_sample(filtered_adc)
    );
    
    wire signed[13:0] agc_out;
    wire signal_detected;
    
    wire signed [symb_width-1:0] ac_signal;
    
    DC_Decouple #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .window(64),
        .kp(1),
        .ki(0),
        .kd(0)
    ) dc_signal_decoupler (
        .clk(clk),
        .rst(0),
        .en(1),
        .new_sample(new_sample),
        .sample(filtered_adc),
        .ac_signal(ac_signal)
    );
    
    AGC #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .kp(5),
        .gkp(-3),
        .win(32)
    ) auto_amp (
        .clk(clk),
        .en(1),
        .rst(0),
        .new_sample(new_sample),
        .in_sample(ac_signal),
        .out_sample(agc_out),
        .signal_detected(signal_detected)
    );
    
    wire reset_costas;
    edgedetect #(
        .DETECT_NEGEDGE(0)
    ) new_signal_detector (
        .clk(clk),
        .rst(0),
        .sig(signal_detected),
        .en(reset_costas)
    );
    
    pulse_generator #( .pulse_width(100) )
        rx_pulse_generator (
            .clk(clk),
            .rst(0),
            .start(signal_detected),
            .sig(led[1])
        );
    
    wire signed [symb_width-1:0] unfiltered_in_phase;
    Costas_Loop #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
//        .SAMPLE_RATE(spl_rate),
//        .CARRIER_FRQ($itor(carrier_frq - (carrier_frq * 0.03))),
        .CARRIER_FRQ(carrier_frq),
        .kp(0.1),
        .ki(0.002),
        .kd(0)
    ) demodulator (
        .clk(clk),
        .rst(reset_costas),
        .en(1),
        .new_sample(new_sample),
        .modulated_input(agc_out),
        .I_component(unfiltered_in_phase)
    );
    
    wire signed [symb_width-1:0] filtered_in_phase;
    
    RRC_Filter #(
        .DWIDTH(symb_width),
        .DFRAC(symb_frac),
        .PIPELEN(3),
        .fixed_gain(-2)
    ) matched_filter (
        .clk(clk),
        .rst(0),
        .in_sample(unfiltered_in_phase),
        .out_sample(filtered_in_phase)
    );
    
    wire signed [symb_width-1:0] symbol;
    wire new_symbol;
    
    Early_Late_TED #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac),
        .SPS(spl_rate / baud_rate),
        .kp(1),
        .ki(0.1),
        .kd(5)
    ) sampler (
        .clk(clk),
        .rst(reset_costas),
        .en(1),
        .sample(filtered_in_phase),
        .new_sample(new_sample),
        .symbol_ready(new_symbol),
        .symbol(symbol)
    );
    
    Symbol_Bit_Mapper #(
        .SYMBOL_WIDTH(symb_width),
        .SYMBOL_FRAC(symb_frac)
    ) symb_to_bits (
        .clk(clk),
        .rst(0),
        .en(signal_detected),
        .symbol(symbol),
        .new_symbol(new_symbol),
        .rx_bit(rx_bit),
        .new_bit(new_bit)
    );
    
    always @ ( posedge clk ) if ( en ) begin
        mod_out <= modulation_product >>> symb_frac;
        offset <= mod_out + symb_one;
        adc_offset <= adc_increased_bits - 14'h0800;
    end
    
    
endmodule

`timescale 1ns / 1ps
`define HALF_PERIOD 41.66
module tb();

    
    reg clk;
    always #`HALF_PERIOD clk = (clk === 1'b0);
    wire cs;
    wire [7:0] dac;
    wire [1:0] led;
    reg reset = 0;
    wire sck;
    reg sdo = 0;
    reg uart_tx;
    wire uart_rx;
    
    cmod_microblaze_wrapper UUT (
        .cs(cs),
        .dac(dac),
        .led(led),
        .reset(reset),
        .sclk(sck),
        .sdo(sdo),
        .sysclk(clk),
        .usb_uart_rxd(uart_tx),
        .usb_uart_txd(uart_rx)
    );
    
endmodule

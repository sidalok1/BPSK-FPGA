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
    
    wireless_system sys (
        .sysclk(sysclk),
        .dac(dac),
        .cs(cs),
        .sclk(sclk),
        .sdo(sdo),
        .led(led),
        .uart_rxd_out(uart_rxd_out)
    );
    
    
endmodule

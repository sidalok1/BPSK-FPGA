module max11108_controller(
    input wire clk, en, rst,
    input wire din,
    output reg [11:0] dout,
    output reg dready,
    output reg sclk, cs
);
    
    reg [11:0] data;
    reg [4:0] counter;
    
    initial begin
        dout = 0;
        dready = 0;
        data = 0;
        counter = 0;
    end
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            dout <= 0;
            dready <= 0;
            data <= 0;
            counter <= 0;
        end else
        if ( en ) begin
            counter <= counter + 1;
            
            case ( counter )
            3, 5, 7, 9, 11, 13,
            15, 17, 19, 21, 23, 25: begin
            
                data[0] <= din;
                data[11:1] <= data[10:0];
                
            end
            26: begin
            
                dout <= data;
                dready <= 1;
                
            end
            default: begin
            
                dready <= 0;
            
            end
            endcase
        end
    end
    
    always @* begin
        sclk = counter[0];
        cs = ( counter == 29 ) ? 1 : 0;
    end
    
endmodule

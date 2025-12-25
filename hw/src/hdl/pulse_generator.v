module pulse_generator
#(
    parameter pulse_width = 1
)
(
    input wire clk, rst, start,
    output reg sig
);

    initial sig = 0;
    
    localparam W = $clog2(pulse_width);
    reg [W-1:0] counter = 0;
    
    localparam WAIT = 0;
    localparam COUNT = 1;
    reg state = WAIT;
    
    always @ ( posedge clk ) begin
    if ( rst ) begin
        sig <= 0;
        counter <= 0;
        state <= WAIT;
    end else begin
        case ( state ) 
        WAIT: begin
            sig <= 0;
            if ( start ) begin
                state <= COUNT;
                counter <= 0;
            end
        end
        COUNT: begin
            sig <= 1;
            if ( counter == pulse_width - 1 ) begin
                state <= WAIT;
            end else begin
                counter <= counter + 1;
            end
        end
        endcase
    end
    end

endmodule

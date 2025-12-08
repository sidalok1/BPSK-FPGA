`default_nettype none

module Controller
#(
    //  Total word length of the output symbols
    parameter SYMBOL_WIDTH  = 16,
    //  Length of the fractional portion of a signal
    parameter SYMBOL_FRAC   = 14,
    //  Output sample rate in hertz
    parameter SAMPLE_RATE   = 6_000_000,
    //  Symbol rate in hertz, together with last value determin sps
    parameter SYMBOL_RATE   = 50_000,
    //  Number of leading bits (before start code) for synchronization
    parameter SYNC_LEN      = 32
)
(
    //  Input clock, should be at the frequency specified by parameter
    input wire                              clk,
    //  General clocked logic enable signal
    input wire                              en,
    //  Synchronous reset
    input wire                              rst,
    //  Signal to begin a transmission
    input wire                              start,
    input wire                              new_sample,
    //  Output symbols in two's complement form at the requested sample rate
    output reg signed [SYMBOL_WIDTH-1:0]    sample,
    
    //  Controller also receives information from receiver hardware
    input wire                              new_bit,
    input wire                              rx_bit,
    output reg                              msg_found,
    output reg                              inv_msg_found,
    output wire                             uart_tx
);
    //  Calculated bitlength of the symbol representing the nonfractional number
    localparam SYMBOL_WHOLE     = SYMBOL_WIDTH - SYMBOL_FRAC;
    //  Two's complement symbols parameterized to given bitwidths
    localparam SYMBOL_ZERO      = {SYMBOL_WIDTH{1'b0}};
    localparam SYMBOL_ONE       = {{SYMBOL_WHOLE-1{1'b0}}, 1'b1, {SYMBOL_FRAC{1'b0}}};
    localparam SYMBOL_NEG_ONE   = {{SYMBOL_WHOLE{1'b1}}, {SYMBOL_FRAC{1'b0}}};
    
    initial begin
        sample          = SYMBOL_ZERO;
        msg_found       = 0;
        inv_msg_found   = 0;
    end
    /*
        Memory containing the output message in ascii. This is hard coded but obviously
        this will ideally not be the case in the future. Should be (relatively) trivial
        to change this to arbitrary messages. Doing so is out of the scope of this demo
    */
    localparam LEN_WIDTH                    = 8;
    localparam reg [LEN_WIDTH-1:0] STR_LEN  = 8'd12;
    localparam STR_BITS = STR_LEN * 8;
    reg [0:STR_BITS-1] message_buffer        = "hello world!";
    reg [0:LEN_WIDTH-1] str_len = STR_LEN;
    /*
        Presently the matlab simulation uses a message length field to indicate how
        long the message is. I am leaning toward changing this to a simple barker
        code at the start and end of the message. The current approach requires the
        receiver to lock on to the message by the first barker code in order to know
        when it has received the full message (and can stop listening). Barker codes at
        either end make it so that the receiver only needs to locked on by the end of
        the message to know when to stop listening (if the start and stop codes are
        different). This does add the complexity that we must worry about the stop code
        appearing in the message.
    */
    localparam START_CODE_LEN                       = 11;
    localparam reg [0:START_CODE_LEN-1] start_code  = 'b11100010010;
    
    //  Symbols per sample
    localparam integer SPS                  = SAMPLE_RATE / SYMBOL_RATE;
    
    //  General registers used for counting indices
    integer idx                             = 0;
    integer jdx                             = 0;
    
    // FSM state register and state definitions
    localparam tx_STATES                    = 6;
    localparam [tx_STATES-1:0] IDLE         = 'b000001;
    localparam [tx_STATES-1:0] PRESYNC      = 'b000010;
    localparam [tx_STATES-1:0] STARTCODE    = 'b000100;
    localparam [tx_STATES-1:0] MSGLEN       = 'b001000;
    localparam [tx_STATES-1:0] MSGBODY      = 'b010000;
    localparam [tx_STATES-1:0] POSTSYNC     = 'b100000;
    reg [tx_STATES-1:0] tx_state            = IDLE;
    
    // Below are combinational block variables used on rhs in clocked block
    // What sample should register on the sample clock
    reg [SYMBOL_WIDTH-1:0] sample_select;
    // Maximum value of idx before state should change
    integer idx_max_val;
    // Combinational assignment of next state value
    reg [tx_STATES-1:0] tx_next;
    
    localparam rx_STATES                    = 4;
    localparam [rx_STATES-1:0] DETECT       = 'b0001;
    localparam [rx_STATES-1:0] READLEN      = 'b0010;
    localparam [rx_STATES-1:0] READBODY     = 'b0100;
    localparam [rx_STATES-1:0] UARTTX       = 'b1000;
    reg [rx_STATES-1:0] rx_state            = DETECT;
    reg invert = 0;
    wire in_bit = invert == 1 ? ~rx_bit : rx_bit;
    reg [START_CODE_LEN-1:0] code           = 0;
    reg [LEN_WIDTH-1:0] rx_len              = 0;
    reg [7:0] rx_buffer [0:255];
    reg write_to_buffer                     = 0;
    reg [7:0] rx_byte                       = 0;
    reg [7:0] uart_byte                     = 0;
    reg send_over_uart                      = 0;
    wire uart_busy;
    integer kdx = 0, hdx = 0;
    
    uarttx #(
        .I_CLK_FRQ(96_000_000),
        .BAUD(115200),
        .PARITY(0),
        .FRAME(8),
        .STOP(1)
    ) uart_transmitter (
        .i_clk(clk),
        .i_en(send_over_uart),
        .i_rst(rst),
        .i_data(uart_byte),
        .o_tx(uart_tx),
        .o_busy(uart_busy)
    );
    
    
    always @ ( posedge clk )
    if ( rst ) begin
        tx_state <= IDLE;
        idx <= 0;
        jdx <= 0;
        sample <= SYMBOL_ZERO;
//        rx_state <= DETECT;
    end else
    if ( en ) begin
        case ( tx_state )
        IDLE: begin
            if ( start ) begin
                idx <= 0;
                jdx <= 0;
                tx_state <= PRESYNC;
            end
        end
        PRESYNC,
        STARTCODE,
        MSGLEN,
        MSGBODY,
        POSTSYNC: begin
            if ( new_sample ) begin
                sample <= sample_select;
                if ( idx == idx_max_val && jdx == SPS - 1 ) begin
                    idx <= 0;
                    jdx <= 0;
                    tx_state <= tx_next;
                end else
                if ( jdx == SPS - 1 ) begin
                    idx <= idx + 1;
                    jdx <= 0;
                end else begin
                    jdx <= jdx + 1;
                end
            end            
        end
        endcase
        
        msg_found <= 0;
        inv_msg_found <= 0;
        
        send_over_uart <= 0;
        write_to_buffer <= 0;
        
        case ( rx_state )
        DETECT: begin
            if ( new_bit ) begin
                code[0] <= rx_bit;
                code[START_CODE_LEN-1:1] <= code[START_CODE_LEN-2:0];
            end
            if ( code == start_code ) begin
                code <= 0;
                msg_found <= 1;
                invert <= 0;
                rx_state <= READLEN;
            end else
            if ( code == ~start_code ) begin
                code <= 0;
                inv_msg_found <= 1;
                invert <= 1;
                rx_state <= READLEN;
            end
            kdx <= 0;
        end
        READLEN: begin
            if ( new_bit ) begin
                rx_len[0] <= in_bit;
                rx_len[LEN_WIDTH-1:1] <= rx_len[LEN_WIDTH-2:0];
                
                if ( kdx == LEN_WIDTH - 1 ) begin
                    kdx <= 0;
                    hdx <= 0;
                    rx_state <= READBODY;
                end else begin
                    kdx <= kdx + 1;
                end
            end
        end
        READBODY: begin
            if ( new_bit ) begin
                rx_byte[0] <= in_bit;
                rx_byte[7:1] <= rx_byte[6:0];
                
                if ( kdx == LEN_WIDTH - 1 ) begin
                    kdx <= 0;
                    write_to_buffer <= 1; // goes low ever other possible cycle
                end else begin
                    kdx <= kdx + 1;
                end
            end
            
            if ( write_to_buffer ) begin
                rx_buffer[hdx] <= rx_byte;
                if ( hdx == rx_len - 1 ) begin
                    hdx <= 0;
                    rx_state <= UARTTX;
                end else begin
                    hdx <= hdx + 1;
                end
            end
        end
        UARTTX: begin
            if ( !uart_busy && !send_over_uart ) begin
                if ( hdx == rx_len ) begin
                    uart_byte <= "\n";
                    hdx <= 0;
                    rx_state <= DETECT;
                end else begin
                    uart_byte <= rx_buffer[hdx];
                    hdx <= hdx + 1;
                end
                send_over_uart <= 1; // goes low every other possible cycle
            end
        end
        endcase
        
        
        
        msg_found <= ( code == start_code ) ? 1 : 0;
        inv_msg_found <= ( code == ~start_code ) ? 1 : 0;
    end
    
    reg [SYMBOL_WIDTH-1:0] current_symbol;
    reg current_bit;
    
    always @* begin
        case ( tx_state )
        // The synchronization is a stream of ones and zeros, which aid both the
        // costas loop and timing error detector.
        PRESYNC: begin 
            current_bit     = idx % 2;
            idx_max_val     = SYNC_LEN - 1;
            tx_next            = STARTCODE;
        end            
        STARTCODE: begin  
            current_bit     = start_code[idx];
            idx_max_val     = START_CODE_LEN - 1;
            tx_next            = MSGLEN;
        end
        MSGLEN: begin
            current_bit     = str_len[idx];
            idx_max_val     = LEN_WIDTH - 1;
            tx_next            = MSGBODY;
        end
        MSGBODY: begin
            current_bit     = message_buffer[idx];
            idx_max_val     = STR_BITS - 1;
            tx_next            = POSTSYNC;
        end
        POSTSYNC: begin
            current_bit     = idx % 2;
            idx_max_val     = SYNC_LEN - 1;
            tx_next            = IDLE;
        end
        default: begin   
            current_bit     = 0;
            idx_max_val     = 0;
            tx_next            = IDLE;
        end
        endcase
        current_symbol = ( current_bit == 0 ) ? SYMBOL_NEG_ONE : SYMBOL_ONE;
        // Recall, for upsampling, a new symbol is added only every SPS, and
        // otherwise is zero
        sample_select = ( jdx == 0 ) ? current_symbol : SYMBOL_ZERO;
    end

endmodule

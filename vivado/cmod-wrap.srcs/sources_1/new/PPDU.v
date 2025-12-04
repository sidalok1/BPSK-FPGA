module PPDU(
    input wire  s00_axis_aclk,
    input wire  s00_axis_aresetn,
    output wire  s00_axis_tready,
    input wire [31:0] s00_axis_tdata,
    input wire  s00_axis_tvalid
    );
    parameter integer DAC_LEN = 8;
    parameter integer MSG_BUFLEN = 64;
    parameter integer BIT_RATE = 400_000;
    parameter integer CARRIER_FRQ = 1_000_000;
    parameter integer SPL_RATE = 4_000_000;
    parameter integer SPS = BIT_RATE / SPL_RATE;


    reg [5:0] m_len;
    
    reg [7:0] m_buffer [0:15][0:3];
    integer idx, bitidx, counter;
    
    localparam IDLE = 'b0001;
    localparam READ = 'b0010;
    localparam PREAMBLE = 'b0100;
    localparam MSG = 'b1000;
    reg [3:0] state = IDLE;
    
    wire clk = s00_axis_aclk;
    wire rst = s00_axis_aresetn;
    wire dvalid = s00_axis_tvalid;
    wire [31:0] data = s00_axis_tdata;
    assign s00_axis_tready = ~rst && (state == IDLE || state == READ);
    wire spl_clk_en;
    clockdiv #(
        .I_CLK_FRQ(100_000_000),
        .FREQUENCY(SPL_RATE)
    ) spl_clk (
        .i_clk(clk),
        .i_rst(rst),
        .o_clk(spl_clk_en)
    ); 
    
    reg next_en = 0;
    reg [DAC_LEN-1:0] upsampled_bit = 0;
    parameter [DAC_LEN-1:0] POS_ONE = 8'b01_000000; // NEEDS TO CHANGE IF DAC_LEN CHANGES
    parameter [DAC_LEN-1:0] NEG_ONE = 8'b11_000000;
    reg sync = 0;
    
    parameter barker_code = 7'b1110010;
    parameter barker_len = 7;
    parameter sync_bits = 16;
    
    always @ ( posedge clk )
    if ( rst ) begin
        m_len <= 0;
        idx <= 0;
        bitidx <= 0;
        counter <= 0;
        upsampled_bit <= 0;
        next_en <= 0;
        sync <= 0;
        state <= IDLE;
    end else begin
        next_en <= 0;
        case ( state )
        IDLE: begin
            if ( dvalid ) begin
                m_len = data[5:0];
                idx <= 0;
                state <= READ;
            end
        end
        READ: begin
            if ( (idx + 1) * 4 >= m_len ) begin 
                state <= PREAMBLE;
                counter <= 0;
                bitidx <= 0;
                upsampled_bit <= 0;
                sync <= 1;
            end else idx <= idx + 1;
            m_buffer[idx][0] <= data[31:24];
            m_buffer[idx][1] <= data[23:16];
            m_buffer[idx][2] <= data[15:8];
            m_buffer[idx][3] <= data[7:0];
        end
        PREAMBLE: begin
            if ( spl_clk_en ) begin
                next_en <= 1;
                if ( counter == SPS - 1 ) begin
                    counter <= 0;
                    if ( sync ) begin
                        if ( bitidx == sync_bits - 1 ) begin
                            sync <= 0;
                            bitidx <= 0;
                        end else bitidx <= bitidx + 1;
                            upsampled_bit <= bitidx % 2 == 1 ? POS_ONE : NEG_ONE;
                    end else begin
                        if ( bitidx == barker_len - 1 ) begin
                            state <= MSG;
                            bitidx <= 0;
                            idx <= 0;
                            counter <= 0;
                        end else bitidx <= bitidx + 1;
                            upsampled_bit <= barker_code[bitidx] ? POS_ONE : NEG_ONE;
                    end
                end else begin
                    counter <= counter + 1;
                    upsampled_bit <= 0;
                end
            end
        end
        MSG: begin
            if ( spl_clk_en ) begin
                next_en <= 1;
                if ( counter == SPS - 1 ) begin
                    counter <= 0;
                    if ( bitidx == 7 ) begin
                        bitidx <= 0;
                        if ( idx == m_len - 1 ) begin
                            idx <= 0;
                            state <= IDLE;
                        end else begin
                            idx <= idx + 1;
                        end
                    end else begin
                        bitidx <= bitidx + 1;
                    end
                    upsampled_bit <= m_buffer[idx/4][idx%4] ? POS_ONE : NEG_ONE;
                end else begin
                    counter <= counter + 1;
                    upsampled_bit <= 0;
                end
            end
        end
        endcase
        
    end
endmodule

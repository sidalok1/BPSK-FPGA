module RRC_Filter
#(
    parameter DWIDTH = 16,
    parameter DFRAC = 14,
    parameter PIPELEN = 3,
    parameter fixed_gain = 2
)
(
    input wire clk, rst,
    input wire signed [DWIDTH-1:0] in_sample,
    output reg signed [DWIDTH-1:0] out_sample
);
    /*
        As opposed to many of the other modules in this project, this module is not
        very parameterized. Indeed, there is already a parameterized FIR filter
        module, but for a filter as big as this one, with far more taps than available
        resources, a bespoke module is needed. The way this module works depends
        heavily on the filter itself, so it would likely need to be reimplemented anyways
        if the original filter changes.
    */
    reg signed [DWIDTH-1:0] taps [0:359], ins [0:359];
    reg signed [DWIDTH-1:0] mults_in_a [0:23], mults_in_b [0:23];
    wire signed [(DWIDTH*2)-1:0] mults_out [0:23];
    reg signed [(DWIDTH*2)-1:0] macs [0:23], macs_summing_stage [0:11], total;
    reg [3:0] idx, sums_idx;
    reg [3:0] mults_in_index;
    wire [3:0] mults_out_index;
    integer i;
    
    
    generate
        genvar g;
        for ( g = 0; g < 24; g = g + 1 ) begin
            PipeMult #(
                .WIDTH_A(DWIDTH),
                .WIDTH_B(DWIDTH),
                .PIPELEN(PIPELEN)
            ) multiplier_pipeline (
                .clk(clk),
                .rst(rst),
                .en(1),
                .a(mults_in_a[g]),
                .b(mults_in_b[g]),
                .r(mults_out[g])
            );
        end
    endgenerate
    
    
    
    PipeSignal #(
        .DWIDTH(4),
        .PIPELEN(PIPELEN)
    ) macs_index_signal_pipe (
        .clk(clk),
        .rst(rst),
        .en(1),
        .i(mults_in_index),
        .o(mults_out_index)
    );
    
    initial begin
        $readmemb("psfilt.mem", taps);
        for ( i = 0; i < 360; i = i + 1 ) ins[i] = 0;
        for ( i = 0; i < 24; i = i + 1 ) begin
            mults_in_a[i] = 0;
            mults_in_b[i] = 0;
            macs[i] = 0;
        end
        for ( i = 0; i < 12; i = i + 1 ) 
            macs_summing_stage[i] = 0;
        mults_in_index = 0;
        total = 0;
        idx = 0;
        sums_idx = 0;
        out_sample = 0;
    end
    
    always @ ( posedge clk ) begin
        if ( rst ) begin
            for ( i = 0; i < 360; i = i + 1 ) ins[i] <= 0;
            for ( i = 0; i < 24; i = i + 1 ) begin
                mults_in_a[i] <= 0;
                mults_in_b[i] <= 0;
                macs[i] <= 0;
            end
            for ( i = 0; i < 12; i = i + 1 ) 
                macs_summing_stage[i] <= 0;
            mults_in_index <= 0;
            total <= 0;
            idx <= 0;
            sums_idx <= 0;
            out_sample <= 0;
        end else begin
            mults_in_index <= idx;
            if ( idx == 15 ) begin
                ins[0] <= in_sample;
                for ( i = 0; i < 359; i = i + 1 ) begin
                    ins[i+1] <= ins[i];
                end
                idx <= 0;
            end else begin
                idx <= idx + 1;
                for ( i = 0; i < 24; i = i + 1 ) begin
                    mults_in_a[i] <= ins[(i*15)+idx];
                    mults_in_b[i] <= taps[(i*15)+idx];
                end
            end
            
            if ( mults_out_index == 15 ) begin
                sums_idx <= 0;
                total <= 0;
                for ( i = 0; i < 12; i = i + 1 ) begin
                    macs_summing_stage[i] <= macs[(2*i)] + macs[(2*i)+1];
                end
                for ( i = 0; i < 24; i = i + 1 ) begin
                    macs[i] <= 0;
                end
            end else begin
                for ( i = 0; i < 24; i = i + 1 ) begin
                    macs[i] <= macs[i] + mults_out[i];
                end
            end
            
            if ( sums_idx < 12 ) begin
                sums_idx <= sums_idx + 1;
                if ( fixed_gain > 0 ) begin
                    total <= total + (macs_summing_stage[sums_idx] <<< fixed_gain);
                end else begin
                    total <= total + (macs_summing_stage[sums_idx] >>> (fixed_gain * -1));
                end
            end else
            if ( sums_idx == 12 ) begin
                out_sample <= total >>> DFRAC;
                sums_idx <= sums_idx + 1;
            end 
        end
    end
    
endmodule

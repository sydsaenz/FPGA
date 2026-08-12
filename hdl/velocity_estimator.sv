`default_nettype none

module velocity_estimator #(parameter int INPUT_WIDTH, int OUTPUT_WIDTH, int CLK_CYCLES_PER_SAMPLE, int INPUT_CLK_FREQ) (
    input wire clk,
    input wire rst,
    input wire signed [INPUT_WIDTH-1:0] pos,
    output logic signed [OUTPUT_WIDTH-1:0] velocity,
    output logic new_data
);

    typedef logic signed [OUTPUT_WIDTH*2-1:0] sample_freq_type;

    localparam sample_freq_type sample_freq = sample_freq_type'(
        real'(INPUT_CLK_FREQ) / real'(CLK_CYCLES_PER_SAMPLE)
    );

    logic [INPUT_WIDTH-1:0] last_pos = 0;

    localparam int TIMER_COUNT_WIDTH = $clog2(CLK_CYCLES_PER_SAMPLE);
    logic [TIMER_COUNT_WIDTH-1:0] timer_count = 0;

    logic signed [OUTPUT_WIDTH-1:0] velocity_intermediate = 0;
    assign velocity = velocity_intermediate;

    logic new_data_intermediate = '0;
    assign new_data = new_data_intermediate;

    always_ff @(posedge clk) begin
        if (rst) begin
            timer_count <= 0;
            last_pos <= pos;
            velocity_intermediate <= 0;
            new_data_intermediate <= 0;
        end else if (timer_count == TIMER_COUNT_WIDTH'(CLK_CYCLES_PER_SAMPLE)) begin
            timer_count <= 0;
            last_pos <= pos;

            /* verilator lint_off WIDTHEXPAND */
            velocity_intermediate <= OUTPUT_WIDTH'(OUTPUT_WIDTH'(signed'(pos - last_pos)) * sample_freq);
            /* verilator lint_on WIDTHEXPAND */
            new_data_intermediate <= 1;

        end else begin
            timer_count <= timer_count + 1;
            new_data_intermediate <= 0;
        end
    end

endmodule // velocity_estimator 

`default_nettype wire

`default_nettype none

module velocity_estimator #(parameter int WIDTH, int CLK_CYCLES_PER_SAMPLE, int INPUT_CLK_FREQ) (
    input wire clk,
    input wire rst,
    input wire signed [WIDTH-1:0] pos,
    output logic signed [WIDTH-1:0] velocity
);

    typedef logic signed [WIDTH*2-1:0] delta_t_type;

    localparam delta_t_type delta_t = delta_t_type'(
        real'(2.0**WIDTH) * real'(INPUT_CLK_FREQ) / real'(CLK_CYCLES_PER_SAMPLE)
    );

    logic [WIDTH-1:0] last_pos = 0;

    localparam int TIMER_COUNT_WIDTH = $clog2(CLK_CYCLES_PER_SAMPLE);
    logic [TIMER_COUNT_WIDTH-1:0] timer_count = 0;

    logic signed [WIDTH-1:0] velocity_intermediate = 0;
    assign velocity = velocity_intermediate;

    always_ff @(posedge clk) begin
        if (rst) begin
            timer_count <= 0;
            last_pos <= pos;
            velocity_intermediate <= 0;
        end else if (timer_count == TIMER_COUNT_WIDTH'(CLK_CYCLES_PER_SAMPLE)) begin
            timer_count <= 0;
            last_pos <= pos;
            velocity_intermediate <= WIDTH'((signed'((WIDTH*2)'(pos) - (WIDTH*2)'(last_pos)) * delta_t) >>> WIDTH);
        end else begin
            timer_count <= timer_count + 1;
        end
    end

endmodule // velocity_estimator 

`default_nettype wire

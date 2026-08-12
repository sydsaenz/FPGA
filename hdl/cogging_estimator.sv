`default_nettype none

// we need to know the exact sample period in advance to do velocity estimation
// we can't have a trigger line because then we would have to divide by the time
// between triggers to determine change in pos per unit time
// this also needs to be coordinated with encoder reads to avoid having
// huge velocity estimate spikes immediately after a read and a zero velocity estimate between reads

// solution: read from the encoder and do velocity estimation in one module?
// this also neatly packs data about both position and velocity in one module
// the velocity ERROR measuring can be handled elsewhere and at a much higher clock speed


// or: extrapolate velocity estimate data
// has the benefit of potentially being smoother at higher velocities




module cogging_estimator #(parameter
    int NUM_HARMONICS,
    int TEETH_PER_REVOLUTION,
    int WIDTH,
    int POS_WIDTH,
    int FRACTION_BITS,
    int CLK_CYCLES_PER_SAMPLE,
    int INPUT_CLK_FREQ,
    real EMA_ALPHA,
    real LEARNING_RATE
) (
    input wire clk,
    input wire rst,
    input wire signed [POS_WIDTH-1:0] pos,
    input wire signed [WIDTH-1:0] vel_command_fxp,
    output logic signed [WIDTH-1:0] cogging_amt_fxp_out
);

    typedef logic signed [WIDTH-1:0] my_signed_int_t;

    function automatic my_signed_int_t real_to_signed_fxp(real num_in);
        return my_signed_int_t'(real'(2.0**FRACTION_BITS) * num_in);
    endfunction

    function automatic logic [WIDTH-1:0] fxp_multiply(logic [WIDTH-1:0] a, logic [WIDTH-1:0] b);
        logic [WIDTH * 2 - 1:0] intermediate = (WIDTH * 2)'(a) * (WIDTH * 2)'(b);
        return (WIDTH)'(intermediate >>> FRACTION_BITS);
    endfunction

    function automatic logic signed [WIDTH-1:0] fxp_signed_multiply(logic signed [WIDTH-1:0] a, logic signed [WIDTH-1:0] b);
        logic signed [WIDTH * 2 - 1:0] intermediate = (WIDTH * 2)'(a) * (WIDTH * 2)'(b);
        return signed'((WIDTH)'(intermediate >>> FRACTION_BITS));
    endfunction

    localparam logic signed [WIDTH-1:0] ema_alpha_fxp = real_to_signed_fxp(EMA_ALPHA);
    localparam logic signed [WIDTH-1:0] learning_rate_fxp = real_to_signed_fxp(LEARNING_RATE);

    logic signed [WIDTH-1:0] cos_coefficients_fxp [NUM_HARMONICS-1:0];
    logic signed [WIDTH-1:0] sin_coefficients_fxp [NUM_HARMONICS-1:0];

    logic signed [NUM_HARMONICS-1:0][WIDTH-1:0] cogging_amt_fxp_adder_queue;
    logic signed [WIDTH-1:0] cogging_amt_fxp_total = 0;
    assign cogging_amt_fxp_out = cogging_amt_fxp_total;

    logic is_vel_estimate_new = '0;
    logic signed [WIDTH-1:0] vel_error_fxp = '0;
    logic signed [WIDTH-1:0] vel_estimate_fxp;
    assign vel_estimate_fxp[FRACTION_BITS-1:0] = '0;
    velocity_estimator #(
        .INPUT_WIDTH(POS_WIDTH),
        .OUTPUT_WIDTH(WIDTH - FRACTION_BITS),
        .CLK_CYCLES_PER_SAMPLE(CLK_CYCLES_PER_SAMPLE),
        .INPUT_CLK_FREQ(INPUT_CLK_FREQ)
    ) vel_estimator(
        .clk(clk),
        .rst(1'b0),
        .pos(pos),
        .velocity(vel_estimate_fxp[WIDTH-1:FRACTION_BITS]),
        .new_data(is_vel_estimate_new)
    );

    logic signed [WIDTH-1:0] learning_rate_times_vel_error_fxp;
    assign learning_rate_times_vel_error_fxp = fxp_signed_multiply(learning_rate_fxp, vel_error_fxp);

    // sum up terms of fourier series and put on output
    generate
        genvar i;
        for (i = 0; i < NUM_HARMONICS; i++) begin
            logic signed [WIDTH-1:0] cos_reference_fxp;
            logic signed [WIDTH-1:0] sin_reference_fxp;
            assign cos_reference_fxp[WIDTH-1:FRACTION_BITS] = '0;
            assign sin_reference_fxp[WIDTH-1:FRACTION_BITS] = '0;
            cordic_cossin #(.WIDTH(FRACTION_BITS), .NUM_ITERATIONS(FRACTION_BITS)) cordic(
                .clk(clk),
                .angle(
                    POS_WIDTH > FRACTION_BITS ? FRACTION_BITS'(pos * i * TEETH_PER_REVOLUTION >>> (POS_WIDTH - FRACTION_BITS))
                    : FRACTION_BITS'(pos * i * TEETH_PER_REVOLUTION <<< (FRACTION_BITS - POS_WIDTH)) ),
                .cos(cos_reference_fxp[FRACTION_BITS-1:0]),
                .sin(sin_reference_fxp[FRACTION_BITS-1:0])
            );
            
            always_ff @(posedge clk) begin
                if (is_vel_estimate_new) begin
                    cos_coefficients_fxp[i] <= cos_coefficients_fxp[i] + fxp_signed_multiply(
                        learning_rate_times_vel_error_fxp, cos_reference_fxp
                    );
                    sin_coefficients_fxp[i] <= sin_coefficients_fxp[i] + fxp_signed_multiply(
                        learning_rate_times_vel_error_fxp, sin_reference_fxp
                    );
                    cogging_amt_fxp_adder_queue[i] <= fxp_signed_multiply(cos_coefficients_fxp[i], cos_reference_fxp)
                        + fxp_signed_multiply(sin_coefficients_fxp[i], sin_reference_fxp);
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (is_vel_estimate_new) begin
            vel_error_fxp <= vel_error_fxp + fxp_signed_multiply(
                (vel_command_fxp - vel_estimate_fxp) - vel_error_fxp,
                ema_alpha_fxp
            );
            cogging_amt_fxp_total <= 0;
        end else begin
            cogging_amt_fxp_adder_queue <= cogging_amt_fxp_adder_queue >> WIDTH;
            cogging_amt_fxp_total <= cogging_amt_fxp_total + cogging_amt_fxp_adder_queue[0];
        end
    end

endmodule

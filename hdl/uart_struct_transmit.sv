`default_nettype none

/*
when trigger is high, outputs din as a series of UART transmissions on dout
*/
module uart_struct_transmit #(parameter WORDS, DATA_BITS, INPUT_CLOCK_FREQ, BAUD_RATE) (
    input wire clk,
    input wire [(WORDS * DATA_BITS - 1):0] din,
    input wire trigger,
    output logic busy,
    output logic dout
);

    localparam TOTAL_BITS = WORDS * DATA_BITS;

    logic [TOTAL_BITS - 1:0] data_buf = '1;
    logic [$clog2(WORDS):0] words_sent = WORDS;
    logic should_transmit;
    logic sending_word;

    uart_transmit #(
        .DATA_BITS(DATA_BITS),
        .INPUT_CLOCK_FREQ(INPUT_CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE))
    word_transmitter(
        .clk(clk),
        .trigger(should_transmit),
        .rst(1'b0),
        .busy(sending_word),
        .din(data_buf[DATA_BITS - 1:0]),
        .dout(dout)
    );

    initial begin
        $display("%d", $clog2(WORDS));
    end

    always_ff @(posedge clk) begin

        if (words_sent < WORDS || sending_word) begin
            if (~sending_word && ~should_transmit) begin // transmission not started
                should_transmit <= 1;
                words_sent <= words_sent + 1;
            end else if (sending_word && should_transmit) begin // transmission was started on last clock cycle
                should_transmit <= 0;
                data_buf <= { {DATA_BITS{1'b1}}, data_buf[TOTAL_BITS - 1 : DATA_BITS] };
            end
        end else if (trigger) begin
            words_sent <= 0;
            data_buf <= din;
            should_transmit <= 0;
        end else begin
            should_transmit <= 0;
        end

    end

endmodule
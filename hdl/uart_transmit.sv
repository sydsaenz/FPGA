`default_nettype none

// transmits a byte over UART when trigger is high
module uart_transmit #(parameter INPUT_CLOCK_FREQ, parameter BAUD_RATE, parameter DATA_BITS) (
    input wire clk,
    input wire rst,
    input wire [7:0] din,
    input wire trigger,
    output logic busy = 1'b0,
    output logic dout = 1'b1
);

    localparam logic [31:0] PERIOD = INPUT_CLOCK_FREQ/BAUD_RATE - 1;
    localparam int TOTAL_BITS = DATA_BITS + 2;

    logic [7:0] data_buf = 8'hFF;
    logic [31:0] count = PERIOD;
    logic [3:0] bits_sent = 11;

    always_ff @(posedge clk) begin

        if (count == PERIOD) begin
            if (bits_sent < TOTAL_BITS) begin // transmission in progress
                count <= 0;
                dout <= data_buf[0];
                data_buf <= {1'b1, data_buf[7:1]};
                bits_sent <= bits_sent + 1'b1;
            end else if (trigger) begin // transmission wanted but not started
                data_buf <= din;
                dout <= 0; // start bit
                count <= 0;
                bits_sent <= 1;
                busy <= 1;
            end else begin // transmission not started and not wanted
                count <= PERIOD;
                dout <= 1;
                busy <= 0;
            end
        end else begin
            count <= count + 1;
        end

    end

endmodule
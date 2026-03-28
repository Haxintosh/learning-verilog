`default_nettype none

module uart_top
#(
    parameter CYCLES_PER_BIT = 234
)
(
    input  wire clk,

    input  wire uartRx,
    output wire uartTx,
    output reg  [5:0] led,

    output wire [7:0] rx_data_out,
    output wire       rx_data_ready,
    input  wire [7:0] tx_data_in,
    input  wire       tx_start,
    output wire       tx_done
);

    wire rx_is_good;

    uart_rx #( .CYCLES_PER_BIT(CYCLES_PER_BIT) ) my_rx (
        .clk(clk),
        .rx_pin(uartRx),
        .rx_data_out(rx_data_out),
        .rx_data_ready(rx_data_ready),
        .rx_data_good(rx_is_good)
    );

    uart_tx #( .CYCLES_PER_BIT(CYCLES_PER_BIT) ) my_tx (
        .clk(clk),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_pin(uartTx),
        .tx_byte_done(tx_done)
    );

    always @(posedge clk) begin
        if (rx_data_ready && rx_is_good) begin
            led <= ~rx_data_out[5:0];
        end
    end

endmodule

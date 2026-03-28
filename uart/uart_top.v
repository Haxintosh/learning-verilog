`default_nettype none

module uart_top
#(
    parameter CYCLES_PER_BIT = 234
)
(
    // hardaware io
    input wire clk,
    input wire uartRx,
    output wire uartTx,
    output reg [5:0] led
);

// rx
wire [7:0] uart_rx_in; // DRIVEN BY SUBMODULES
wire rx_data_ready;
wire rx_data_good;

// tx
reg [7:0] uart_tx_out; // reg since driven by this
reg tx_start;
wire tx_done;

reg [3:0] state = 0;

uart_tx #(
    .CYCLES_PER_BIT(234)
) uart_tx_inst (
    .clk(clk),
    .tx_start(tx_start),
    .tx_data_in(uart_tx_out),
    .tx_pin(uartTx),
    .tx_byte_done(tx_done)
);

uart_rx #(
    .CYCLES_PER_BIT(234)
) uart_rx_inst (
    .clk(clk),
    .rx_data_out(uart_rx_in),
    .rx_pin(uartRx),
    .rx_data_ready(rx_data_ready),
    .rx_data_good(rx_data_good)
);


// fsm

localparam IDLE  = 0;
localparam START = 1;
localparam WAIT  = 2;


always @(posedge clk) begin
    case (state)
        IDLE: begin
            // if we have data form rx to send back
            if (rx_data_ready) begin
                uart_tx_out <= uart_rx_in;
                tx_start<=1;
                state<= START;
            end
        end
        START: begin
            tx_start <=0; // only pull it high for 1 cycle
            state <= WAIT;
        end
        WAIT: begin
            if (tx_done && ~rx_data_ready) begin // wait until next data rdy event
                state <= IDLE;
            end
        end
    endcase
end
endmodule

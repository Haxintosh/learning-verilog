`default_nettype none

module uart_rx
#(
    parameter CYCLES_PER_BIT = 234
)
(
    input wire clk,
    input wire rx_pin,           // previously uartRx
    output reg [7:0] rx_data_out,// previously data
    output reg rx_data_ready,    // previously byteReady
    output reg rx_data_good      // previously byteGood
);

localparam CYCLES_PER_READ = (CYCLES_PER_BIT/2); // read at the middle of a bit in case of clock wonkyness

// rx registers
reg [3:0]  state = 0;          // state of the uart state machine (previously rxState)
reg [12:0] cycle_counter = 0;  // number of clock cycle in current rx (previously rxCounter)
reg [2:0]  bit_index = 0;      // number of rx data bits read since start bit (previously rxBitNumber)
reg [7:0]  rx_shift_reg = 0;   // 8 bit uart rx data (previously dataIn)
reg        parity_calc = 0;    // parity flip per 1 this is for odd parity (previously rxParity)

localparam STATE_IDLE = 0;
localparam STATE_START_BIT = 1;
localparam STATE_READ_WAIT = 2;
localparam STATE_READ = 3;
localparam STATE_PARITY_BIT = 5;
localparam STATE_STOP_BIT = 6;

always @(posedge clk) begin
    case (state)
        STATE_IDLE: begin
            if (rx_pin == 0) begin // reset if it's pulled low
                state <= STATE_START_BIT;
                cycle_counter <= 1; // we start the read clock counter
                bit_index <= 0;
                rx_data_ready <= 0; // no data is indeed not ready
                rx_data_good <= 0; // we don't know if the data is good or not
                parity_calc <= 0; // reset parity
            end
        end
        STATE_START_BIT: begin
            if (cycle_counter == CYCLES_PER_READ) begin
                state <= STATE_READ_WAIT;
                cycle_counter <= 1;
                rx_shift_reg <= 0;
            end else
                cycle_counter <= cycle_counter + 1;
        end
        STATE_READ_WAIT: begin
            cycle_counter <= cycle_counter + 1;
            if ((cycle_counter+1) == CYCLES_PER_BIT) begin
                state <= STATE_READ;
            end
        end
        STATE_READ: begin
            cycle_counter <= 1;
            rx_shift_reg <= {rx_pin, rx_shift_reg[7:1]};
            bit_index <= bit_index + 1;
            if (rx_pin == 1) begin
                parity_calc <= ~parity_calc;
            end
            if (bit_index == 7) begin
                state <= STATE_PARITY_BIT;
                // // rxState <= RX_STATE_STOP_BIT; // no parity bit
            end else
                state <= STATE_READ_WAIT;
        end
        STATE_PARITY_BIT: begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == CYCLES_PER_BIT) begin
                if (rx_pin == parity_calc) begin
                    rx_data_good <= 1;
                end
                state <= STATE_STOP_BIT;
                cycle_counter <= 1;
            end
        end
        STATE_STOP_BIT: begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == CYCLES_PER_BIT) begin
                state <= STATE_IDLE;
                rx_data_ready <= 1;
                cycle_counter <= 1;
                if (rx_data_good) begin
                    rx_data_out <= rx_shift_reg;
                end else begin
                    rx_data_out <= 0;
                end
            end
        end
    endcase
end

endmodule

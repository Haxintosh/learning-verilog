`default_nettype none

module uart_tx
#(
    parameter CYCLES_PER_BIT = 234
)
(
    input wire clk,
    input wire tx_start,         // 1-cycle pulse to start sending
    input wire [7:0] tx_data_in, // The byte you want to send
    output reg tx_pin,
    output reg tx_byte_done      // Pulses high when finished
);

// TX registers
reg [3:0]  state = 0;
reg [12:0] cycle_counter = 0;
reg [2:0]  bit_index = 0;
reg [7:0]  tx_data_reg = 0;   // Register to hold data while sending
reg        parity_calc = 0;

localparam  STATE_IDLE = 0;
localparam  STATE_START_BIT = 1;
localparam  STATE_SEND_WAIT = 2;
localparam  STATE_SEND = 3;
localparam  STATE_PARITY_BIT = 5;
localparam  STATE_STOP_BIT = 6;
localparam  STATE_STOP_DELAY = 7;

always @(posedge clk) begin
    case (state)
        STATE_IDLE: begin
            tx_pin <= 1;
            if (tx_start) begin
                state <= STATE_START_BIT;
                cycle_counter <= 1;
                bit_index <= 0;
                tx_byte_done <= 0;
                parity_calc <= 0;
                tx_data_reg <= tx_data_in; // Latch the incoming data so it doesn't change mid-send
            end
        end
        STATE_START_BIT: begin
            tx_pin <= 0; // pull low to start
            if (cycle_counter == CYCLES_PER_BIT) begin
                state <= STATE_SEND;
                cycle_counter <= 1;
            end else begin
                cycle_counter <= cycle_counter + 1;
            end
        end
        STATE_SEND_WAIT: begin
            cycle_counter <= cycle_counter + 1;
            if ((cycle_counter+1) == CYCLES_PER_BIT) begin
                state <= STATE_SEND;
            end
        end
        STATE_SEND: begin
            cycle_counter <= 1;
            tx_pin <= tx_data_reg[bit_index];
            if (tx_data_reg[bit_index]) begin // lsb to msb
                parity_calc <= ~parity_calc;
            end
            bit_index <= bit_index + 1;
            if (bit_index == 7) begin
                state <= STATE_PARITY_BIT;
            end else
                state <= STATE_SEND_WAIT;
        end
        STATE_PARITY_BIT: begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == CYCLES_PER_BIT) begin
                tx_pin <= parity_calc;
                state <= STATE_STOP_BIT;
                cycle_counter <= 1;
            end
        end
        STATE_STOP_BIT: begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == CYCLES_PER_BIT) begin
                tx_pin <= 1; // pull high for stop bit and return to idle state
                state <= STATE_STOP_DELAY;
                cycle_counter <= 1;
            end
        end
        STATE_STOP_DELAY: begin
            cycle_counter <= cycle_counter+1;
            if (cycle_counter == CYCLES_PER_BIT) begin
                cycle_counter <= 1;
                tx_byte_done <= 1; // Signal to the outside world we are done
                state <= STATE_IDLE;
            end
        end
    endcase
end

endmodule

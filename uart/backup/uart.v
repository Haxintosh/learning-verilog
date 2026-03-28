`default_nettype none

module uart
#(
    parameter CYCLES_PER_BIT = 234
)
(
    input clk,
    input uartRx,
    output reg uartTx,
    output reg [5:0] led,
    input btn1
);

localparam CYCLES_PER_READ = (CYCLES_PER_BIT/2); // read at the middle of a bit in case of clock wonkyness
// rx registers
reg [3:0] rxState = 0; // state of the uart state machine
reg [12:0] rxCounter = 0; // number of clock cycle in current rx
reg [2:0] rxBitNumber = 0; // number of rx data bits read since start bit
reg [7:0] dataIn = 0; // 8 bit uart rx data
reg [7:0] data = 0;
reg rxParity = 0; // parity flip per 1 this is for odd parity
reg byteGood = 0; // if passes parity check
reg byteReady = 0; // if all the 8 bits of rx are read or nah

localparam RX_STATE_IDLE = 0;
localparam RX_STATE_START_BIT = 1;
localparam RX_STATE_READ_WAIT = 2;
localparam RX_STATE_READ = 3;
localparam RX_STATE_PARITY_BIT = 5;
localparam RX_STATE_STOP_BIT = 6;

// TX registers
reg [3:0] txState = 0; // state of the uart state machine
reg [12:0] txCounter = 0; // number of clock cycle in current tx
reg [2:0] txBitNumber = 0; // number of tx data bits sent since start bit
reg [7:0] txData = 'b10101010;
reg txParity = 0; // parity flip per 1 this is for even parity
reg txDataReady = 0; // if we have tx data to send over
reg txByteDone = 0; // if we finished sending over the data

localparam  TX_STATE_IDLE = 0;
localparam  TX_STATE_START_BIT = 1;
localparam  TX_STATE_SEND_WAIT = 2;
localparam  TX_STATE_SEND = 3;
localparam  TX_STATE_PARITY_BIT = 5;
localparam  TX_STATE_STOP_BIT = 6;
localparam  TX_STATE_STOP_DELAY = 7; // aka stop bit end delay to allow for the other side to process


always @(posedge clk) begin
    case (rxState)
        RX_STATE_IDLE: begin
            if (uartRx == 0) begin // reset if it's pulled low
                rxState <= RX_STATE_START_BIT;
                rxCounter <= 1; // we start the read clock counter
                rxBitNumber <= 0;
                byteReady <= 0; // no data is indeed not ready
                byteGood <= 0; // we don't know if the data is good or not
                rxParity <= 0; // reset parity
            end
        end
        RX_STATE_START_BIT: begin
            if (rxCounter == CYCLES_PER_READ) begin
                rxState <= RX_STATE_READ_WAIT;
                rxCounter <= 1;
                dataIn <= 0;
            end else
                rxCounter <= rxCounter + 1;
        end
        RX_STATE_READ_WAIT: begin
            rxCounter<= rxCounter +1;
            if ((rxCounter+1) == CYCLES_PER_BIT) begin
                rxState <= RX_STATE_READ;
            end
        end
        RX_STATE_READ: begin
            rxCounter <= 1;
            dataIn <= {uartRx, dataIn[7:1]};
            rxBitNumber <= rxBitNumber + 1;
            if (uartRx==1) begin
                rxParity <= ~rxParity;
            end
            if (rxBitNumber == 7) begin
                rxState <= RX_STATE_PARITY_BIT;
                // // rxState <= RX_STATE_STOP_BIT; // no parity bit
            end else
                rxState <= RX_STATE_READ_WAIT;
        end
        RX_STATE_PARITY_BIT: begin
            rxCounter <= rxCounter + 1;
            if (rxCounter==CYCLES_PER_BIT) begin
                if (uartRx == rxParity) begin
                    byteGood <= 1;
                end
                rxState <= RX_STATE_STOP_BIT;
                rxCounter <= 1;
            end
        end
        RX_STATE_STOP_BIT: begin
            rxCounter <= rxCounter + 1;
            if (rxCounter == CYCLES_PER_BIT) begin
                rxState <= RX_STATE_IDLE;
                byteReady <= 1;
                rxCounter <= 1;
                if (byteGood) begin
                    data <= dataIn;
                end else begin
                    data <= 0;
                end
            end
        end
    endcase
end
always @(posedge clk) begin
    case (txState)
        TX_STATE_IDLE: begin
            uartTx <= 1;
            if (txDataReady) begin
                txState <= TX_STATE_START_BIT;
                txCounter <= 1;
                txBitNumber <= 0;
                txByteDone <= 0;
                txParity <= 0;
            end
        end
        TX_STATE_START_BIT: begin
            // txState <= TX_STATE_SEND_WAIT;
            // txCounter <= 1;
            uartTx <= 0;// pull low to start
            if (txCounter == CYCLES_PER_BIT) begin
                txState <= TX_STATE_SEND;
                txCounter <= 1;
            end else begin
                txCounter <= txCounter + 1;
            end
        end
        TX_STATE_SEND_WAIT: begin
            txCounter <= txCounter + 1;
            if ((txCounter+1) == CYCLES_PER_BIT) begin
                txState <= TX_STATE_SEND;
            end
        end
        TX_STATE_SEND: begin
            txCounter <= 1;
            uartTx <= txData[txBitNumber];
            if (txData[txBitNumber]) begin // lsb to msb
                txParity <= ~txParity;
            end
            txBitNumber <= txBitNumber + 1;
            if (txBitNumber == 7) begin
                txState <=TX_STATE_PARITY_BIT;
            end else
                txState <= TX_STATE_SEND_WAIT;
        end
        TX_STATE_PARITY_BIT: begin
            txCounter <= txCounter + 1;
            if (txCounter==CYCLES_PER_BIT) begin
                uartTx <= txParity;
                txState <= TX_STATE_STOP_BIT;
                txCounter <= 1;
            end
        end
        TX_STATE_STOP_BIT: begin
            txCounter <= txCounter + 1;
            if (txCounter == CYCLES_PER_BIT) begin
                uartTx <= 1; // pull high for stop bit and return to idle state
                // we need to wait for another cycle...
                txState <= TX_STATE_STOP_DELAY;
                txCounter <= 1;
            end
        end
        TX_STATE_STOP_DELAY: begin
            txCounter <= txCounter+1;
            if (txCounter == CYCLES_PER_BIT) begin
                txCounter <= 1;
                txByteDone <= 1;
                txDataReady <= 0;
                txState <= TX_STATE_IDLE;
            end
        end
    endcase
end
always @(posedge clk) begin
    if (byteReady) begin
        led <= ~dataIn[5:0];
    end
end

always @(posedge btn1) begin
    txDataReady <= 1;
end
endmodule

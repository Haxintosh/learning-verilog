`default_nettype none

module uart
#(
    parameter CYCLES_PER_BIT = 234
)
(
    input clk,
    input uartRx,
    output uartTx,
    output reg [5:0] led,
    input btn1
);

localparam CYCLES_PER_READ = (CYCLES_PER_BIT/2); // read at the middle of a bit in case of clock wonkyness

reg [3:0] rxState = 0; // state of the uart state machine
reg [12:0] rxCounter = 0; // number of clock cycle in current rx
reg [2:0] rxBitNumber = 0; // number of rx data bits read since start bit
reg [7:0] dataIn = 0; // 8 bit uart rx data
reg byteReady = 0; // if all the 8 bits of rx are read or nah

localparam RX_STATE_IDLE = 0;
localparam RX_STATE_START_BIT = 1;
localparam RX_STATE_READ_WAIT = 2;
localparam RX_STATE_READ = 3;
localparam RX_STATE_STOP_BIT = 5;

always @(posedge clk) begin
    case (rxState)
        RX_STATE_IDLE: begin
            if (uartRx == 0) begin // reset if it's pulled low
                rxState <= RX_STATE_START_BIT;
                rxCounter <= 1; // we start the read clock counter
                rxBitNumber <= 0;
                byteReady <= 0; // no data is indeed not ready 
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
            if (rxBitNumber == 7) begin
                rxState <= RX_STATE_STOP_BIT;
            end else 
                rxState <= RX_STATE_READ_WAIT;
        end
        RX_STATE_STOP_BIT: begin
            rxCounter <= rxCounter + 1;
            if (rxCounter == CYCLES_PER_BIT) begin
                rxState <= RX_STATE_IDLE;
                byteReady <= 1;
                rxCounter <= 0;
            end 
        end
    endcase
end

always @(posedge clk) begin
    if (byteReady) begin
        led <= ~dataIn[5:0];
    end
end
endmodule
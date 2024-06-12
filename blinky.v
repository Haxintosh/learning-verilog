module top
(
    input clk,
    output [5:0] led
);

localparam WAIT_TIME = 13500000;
reg [5:0] ledCounter = 1;
reg [23:0] clockCounter = 0;
reg ledDir = 0;

always @(posedge clk) begin
    clockCounter <= clockCounter + 1;
    if (clockCounter == WAIT_TIME) begin
        clockCounter <= 0;

        if (ledDir == 0) begin
            ledCounter <= ledCounter << 1;
            if (ledCounter == 6'b100000) begin
                ledDir <= 1;
                ledCounter <= 6'b010000;
            end
        end 

        if (ledDir == 1) begin
            ledCounter <= ledCounter >> 1;
            if (ledCounter == 6'b000001) begin
                ledDir <= 0;
                ledCounter <= 6'b000010;
            end
        end
    end
end
assign led = ~ledCounter;
endmodule
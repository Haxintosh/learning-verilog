`default_nettype none
`timescale 1ns/1ns
// this was ai generated
module test();

  // ---------------------------------------------------------
  // Signals & Parameters
  // ---------------------------------------------------------
  reg clk = 0;
  reg uartRx = 1;
  wire uartTx;
  wire [5:0] led;

  localparam CYCLES_PER_BIT = 234;
  localparam CLOCK_PERIOD = 2;
  localparam BIT_PERIOD = CYCLES_PER_BIT * CLOCK_PERIOD;

  // ---------------------------------------------------------
  // Device Under Test (DUT)
  // ---------------------------------------------------------
  uart_top #(
    .CYCLES_PER_BIT(CYCLES_PER_BIT)
  ) dut (
    .clk(clk),
    .uartRx(uartRx),
    .uartTx(uartTx),
    .led(led)
  );

  // Clock generation
  always #(CLOCK_PERIOD/2) clk = ~clk;

  // ---------------------------------------------------------
  // TASK: Send byte to the FPGA (Host -> FPGA)
  // ---------------------------------------------------------
  task send_byte;
    input [7:0] data;
    reg parity_bit;
    integer i;
    begin
      // XOR reduction calculates the EVEN parity bit automatically
      parity_bit = ^data;
      $display($time, " | [HOST TX] Sending data: 8'h%h | Parity: %b", data, parity_bit);

      // 1. Start bit
      uartRx = 0;
      #(BIT_PERIOD);

      // 2. Data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        uartRx = data[i];
        #(BIT_PERIOD);
      end

      // 3. Parity bit (EVEN)
      uartRx = parity_bit;
      #(BIT_PERIOD);

      // 4. Stop bit
      uartRx = 1;
      #(BIT_PERIOD);
    end
  endtask

  // ---------------------------------------------------------
  // TASK: Monitor and verify echoed byte (FPGA -> Host)
  // ---------------------------------------------------------
  task expect_byte;
    input [7:0] expected_data;
    reg [7:0] captured_data;
    reg captured_parity;
    reg expected_parity;
    integer i;
    begin
      // What the parity bit *should* be
      expected_parity = ^expected_data;

      // Wait for the start bit (falling edge on uartTx)
      @(negedge uartTx);

      // Delay by half a bit period to sample in the middle of the bit
      #(BIT_PERIOD / 2);

      if (uartTx !== 0) $display($time, " | [HOST RX] Error: Invalid start bit!");
      #(BIT_PERIOD);

      // Read 8 data bits
      for (i = 0; i < 8; i = i + 1) begin
        captured_data[i] = uartTx;
        #(BIT_PERIOD);
      end

      // Read parity bit
      captured_parity = uartTx;
      #(BIT_PERIOD);

      // Read stop bit
      if (uartTx !== 1) $display($time, " | [HOST RX] Error: Invalid stop bit!");

      // Verify the echo (Both Data and Parity must match)
      if ((captured_data === expected_data) && (captured_parity === expected_parity))
        $display($time, " | [HOST RX] SUCCESS: Echo matched! Received: 8'%b | Parity: %b",
                 captured_data, captured_parity);
      else
        $display($time, " | [HOST RX] FAIL: Expected 8'b%b (Parity %b), but got 8'b%b (Parity %b)",
                 expected_data, expected_parity, captured_data, captured_parity);
    end
  endtask

  // ---------------------------------------------------------
  // TASK: Wrapper to test a full echo cycle concurrently
  // ---------------------------------------------------------
  task run_echo_test;
    input [7:0] test_data;
    begin
      fork
        // Thread 1: Send the data
        send_byte(test_data);

        // Thread 2: Receive and verify the echo
        expect_byte(test_data);
      join

      // Idle time between tests
      #(BIT_PERIOD * 6);
    end
  endtask

  // ---------------------------------------------------------
  // MAIN TEST SEQUENCE
  // ---------------------------------------------------------
  initial begin
    $display("Starting EVEN Parity UART Echo Tests");
    $dumpfile("uart_echo.vcd");
    $dumpvars(0, test);

    // Initialize
    uartRx = 1;
    #(BIT_PERIOD * 2);

    // Run Echo Tests
    $display("\n--- Test 1: Echo 0x55 (Alternating 01010101) ---");
    run_echo_test(8'h55);

    $display("\n--- Test 2: Echo 0xAA (Alternating 10101010) ---");
    run_echo_test(8'hAA);

    $display("\n--- Test 3: Echo 0x00 (All Zeros) ---");
    run_echo_test(8'h00);

    $display("\n--- Test 4: Echo 0xFF (All Ones) ---");
    run_echo_test(8'hFF);

    $display("\n--- Test 5: Echo 0x4A (Random Data) ---");
    run_echo_test(8'h4A);

    $display("\nTests Completed.");
    $finish;
  end

endmodule

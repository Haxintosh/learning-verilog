module test();
  reg clk = 0;
  reg uart_rx = 1;
  wire uart_tx;
  wire [5:0] led;
  reg btn = 0; // Initialize low so we can pull it high later

  localparam BIT_PERIOD = 16;

  uart #(8'd8) u(
    clk,
    uart_rx,
    uart_tx,
    led,
    btn
  );

  always
    #1 clk = ~clk;

  // ---------------------------------------------------------
  // TASK: Send a UART byte (Simulating RX into the module)
  // ---------------------------------------------------------
  task send_byte;
    input [7:0] data;
    input parity_bit;
    integer i;
    begin
      // 1. Start bit
      uart_rx = 0;
      #(BIT_PERIOD);

      // 2. Data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        uart_rx = data[i];
        #(BIT_PERIOD);
      end

      // 3. Parity bit
      uart_rx = parity_bit;
      #(BIT_PERIOD);

      // 4. Stop bit
      uart_rx = 1;
      #(BIT_PERIOD);

      // Idle time between bytes
      #(BIT_PERIOD * 2);
    end
  endtask

  // ---------------------------------------------------------
  // TASK: Capture a UART byte (Monitoring TX from the module)
  // ---------------------------------------------------------
  task capture_tx;
    reg [7:0] captured_data;
    reg captured_parity;
    integer i;
    begin
      // Wait for the start bit (falling edge on uart_tx)
      @(negedge uart_tx);

      // Delay by half a bit period to sample in the middle of the bit
      #(BIT_PERIOD / 2);

      if (uart_tx !== 0) $display("TX Error: Invalid start bit!");
      #(BIT_PERIOD);

      // Read 8 data bits
      for (i = 0; i < 8; i = i + 1) begin
        captured_data[i] = uart_tx;
        #(BIT_PERIOD);
      end

      // Read parity bit
      captured_parity = uart_tx;
      #(BIT_PERIOD);

      // Read stop bit
      if (uart_tx !== 1) $display("TX Error: Invalid stop bit!");

      $display($time, " | Captured TX Data: %b (0x%h) | TX Parity: %b",
               captured_data, captured_data, captured_parity);
    end
  endtask

  // ---------------------------------------------------------
  // MAIN TEST SEQUENCE
  // ---------------------------------------------------------
  initial begin
    $display("Starting EVEN Parity UART RX/TX Tests");
    $monitor($time, " | LED Value: %b | RX: %b | TX: %b | BTN: %b",
             led, uart_rx, uart_tx, btn);

    $dumpfile("uart.vcd");
    $dumpvars(0, test);

    // Initialize inputs
    uart_rx = 1;
    btn = 0;
    #20;

    // ==========================================
    // VALID DATA TESTS (Correct EVEN Parity)
    // ==========================================

    // --- Test 1: Original Byte ---
    $display("\n--- Test Case 1: 0x61 (01100001) - Valid EVEN Parity ---");
    // Three 1s (odd). Parity must be 1 to make the total even (4).
    send_byte(8'b01100001, 1'b1);

    // --- Test 2: Alternating Bits ---
    $display("\n--- Test Case 2: 0xA5 (10100101) - Valid EVEN Parity ---");
    // Four 1s (even). Parity must be 0 to keep the total even (4).
    send_byte(8'hA5, 1'b0);

    // --- Test 3: Boundary - All Ones ---
    $display("\n--- Test Case 3: 0xFF (11111111) - Valid EVEN Parity ---");
    // Eight 1s (even). Parity must be 0 to keep the total even (8).
    send_byte(8'hFF, 1'b0);

    // --- Test 4: Boundary - All Zeros ---
    $display("\n--- Test Case 4: 0x00 (00000000) - Valid EVEN Parity ---");
    // Zero 1s (even). Parity must be 0 to keep the total even (0).
    send_byte(8'h00, 1'b0);


    // ==========================================
    // ERROR TESTS (Bad EVEN Parity)
    // ==========================================

    // --- Test 5: Bad Parity on Alternating Bits ---
    $display("\n--- Test Case 5: 0x5A (01011010) - BAD EVEN Parity ---");
    // Four 1s. Correct even parity is 0. We intentionally send 1.
    // Total 1s = 5 (Odd). This should trigger an error in your module.
    send_byte(8'h5A, 1'b1);

    // --- Test 6: Bad Parity on All Zeros ---
    $display("\n--- Test Case 6: 0x00 (00000000) - BAD EVEN Parity ---");
    // Zero 1s. Correct even parity is 0. We intentionally send 1.
    // Total 1s = 1 (Odd). This should trigger an error.
    send_byte(8'h00, 1'b1);

    #(BIT_PERIOD * 4); // Breathing room before TX test


    // ==========================================
    // TX TEST (Triggered by Button)
    // ==========================================

    $display("\n--- Test Case 7: Pulling btn HIGH to trigger TX ---");

    fork
        // Thread 1: Start listening on the TX line immediately
        begin
        $display("Waiting for module to transmit on uart_tx...");
        capture_tx();
        end

        // Thread 2: Press and release the button
        begin
        btn = 1;
        #(BIT_PERIOD * 2);
        btn = 0;
        end
    join

    // Give the simulator a little time to settle after the stop bit
    #(BIT_PERIOD * 4);
    $display("\nTests Completed.");
    $finish;
  end

endmodule

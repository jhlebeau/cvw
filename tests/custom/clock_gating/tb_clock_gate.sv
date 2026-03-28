`timescale 1ns/1ps

module tb_clock_gate;

    // DUT signals
    logic clk_in;
    logic enable;
    logic clk_out;

    // Instantiate DUT
    clock_gate dut (
        .clk_in (clk_in),
        .enable (enable),
        .clk_out(clk_out)
    );

    // --------------------------------
    // Clock generation: 10 ns period
    // --------------------------------
    initial clk_in = 0;
    always #5 clk_in = ~clk_in;

    // --------------------------------
    // Stimulus: mid-cycle enable flips
    // --------------------------------
    initial begin
        enable = 0;

        // Let clock settle
        #12;

        // Toggle enable while clk is HIGH (should NOT latch)
        $display("[%0t] enable -> 1 (clk HIGH)", $time);
        enable = 1;

        // Wait into low phase so latch can capture
        #8;

        // Toggle enable while clk is LOW (should latch immediately)
        $display("[%0t] enable -> 0 (clk LOW)", $time);
        enable = 0;

        // Toggle enable again during HIGH
        #3;
        $display("[%0t] enable -> 1 (clk HIGH)", $time);
        enable = 1;

        // test enable during clk high
        #15;
        enable = 0;
        #10;
        enable = 1;

        // Let several cycles run
        #30;

        $display("[%0t] Test complete", $time);
        $finish;
    end

    // --------------------------------
    // Monitor (fine-grain visibility)
    // --------------------------------
    always @(clk_in or enable or clk_out) begin
        $display("[%0t] clk=%0b enable=%0b latched=%0b clk_out=%0b",
                 $time, clk_in, enable, dut.latched_enable, clk_out);
    end

endmodule

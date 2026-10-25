// ============================================================================
// Self-checking regression testbench for booth_radix2 (pass/fail only)
//   - N = 8  : exhaustive (all 65,536 operand pairs)
//   - N = 7  : exhaustive (odd width)
//   - N = 16 : corner cases + 100,000 random vectors
// ============================================================================
`timescale 1ns / 1ps

module tb_booth_radix2_random;

    // ---------------- N = 8 ----------------
    reg  signed [7:0]  a8, b8;
    wire signed [15:0] p8;
    booth_radix2 #(.N(8)) dut8 (.a(a8), .b(b8), .p(p8));

    // ---------------- N = 7 ----------------
    reg  signed [6:0]  a7, b7;
    wire signed [13:0] p7;
    booth_radix2 #(.N(7)) dut7 (.a(a7), .b(b7), .p(p7));

    // ---------------- N = 16 ---------------
    reg  signed [15:0] a16, b16;
    wire signed [31:0] p16;
    booth_radix2 #(.N(16)) dut16 (.a(a16), .b(b16), .p(p16));

    integer i, j, errors, tests;
    reg signed [15:0] corner [0:7];

    task check16;
        begin
            #1;
            tests = tests + 1;
            if (p16 !== a16 * b16) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL N=16: %0d * %0d = %0d (expected %0d)",
                             a16, b16, p16, a16 * b16);
            end
        end
    endtask

    initial begin
        errors = 0;
        tests  = 0;

        // ---- exhaustive 8-bit ----
        for (i = -128; i < 128; i = i + 1)
            for (j = -128; j < 128; j = j + 1) begin
                a8 = i; b8 = j; #1;
                tests = tests + 1;
                if (p8 !== a8 * b8) begin
                    errors = errors + 1;
                    if (errors <= 10)
                        $display("FAIL N=8 : %0d * %0d = %0d (expected %0d)",
                                 a8, b8, p8, a8 * b8);
                end
            end

        // ---- exhaustive 7-bit ----
        for (i = -64; i < 64; i = i + 1)
            for (j = -64; j < 64; j = j + 1) begin
                a7 = i; b7 = j; #1;
                tests = tests + 1;
                if (p7 !== a7 * b7) begin
                    errors = errors + 1;
                    if (errors <= 10)
                        $display("FAIL N=7 : %0d * %0d = %0d (expected %0d)",
                                 a7, b7, p7, a7 * b7);
                end
            end

        // ---- 16-bit corner cases ----
        corner[0] = 16'sh0000; corner[1] = 16'sh0001;
        corner[2] = 16'shFFFF; corner[3] = 16'sh7FFF;
        corner[4] = 16'sh8000; corner[5] = 16'sh8001;
        corner[6] = 16'sh5555; corner[7] = 16'shAAAA;
        for (i = 0; i < 8; i = i + 1)
            for (j = 0; j < 8; j = j + 1) begin
                a16 = corner[i]; b16 = corner[j];
                check16;
            end

        // ---- 16-bit random ----
        for (i = 0; i < 100000; i = i + 1) begin
            a16 = $random; b16 = $random;
            check16;
        end

        if (errors == 0)
            $display("PASS: all %0d tests passed", tests);
        else
            $display("FAILED: %0d / %0d tests failed", errors, tests);
        $finish;
    end

endmodule

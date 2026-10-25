// ============================================================================
// Directed testbench for booth_radix4 (waveform / simulation viewing)
//   - N = 8, 18 hand-picked cases, one every 10 ns
//   - Dumps all signals (including DUT internals) to booth_radix4_directed.vcd
// ============================================================================
`timescale 1ns / 1ps

module tb_booth_radix4_directed;

    reg  signed [7:0]  a, b;
    wire signed [15:0] p;
    reg  signed [15:0] expected;

    booth_radix4 #(.N(8)) dut (.a(a), .b(b), .p(p));

    integer errors = 0;
    integer tests  = 0;

    task run;
        input signed [7:0] ta, tb;
        begin
            a = ta; b = tb; expected = ta * tb;
            #10;
            tests = tests + 1;
            if (p !== expected) errors = errors + 1;
            $display("%4d | %5d | %5d | %7d | %7d | %s",
                     tests, a, b, p, expected,
                     (p === expected) ? "PASS" : "FAIL");
        end
    endtask

    initial begin
        $dumpfile("booth_radix4_directed.vcd");
        $dumpvars(0, tb_booth_radix4_directed);

        $display("  #  |     a |     b |       p | expected | result");
        $display("-----+-------+-------+---------+----------+-------");

        // zero / identity
        run(   0,    0);
        run(   0,   57);
        run(   1,    1);
        run(   1,   -1);
        run(  -1,   -1);

        // sign combinations
        run(   7,    3);
        run(  -7,    3);
        run(   7,   -3);
        run(  -7,   -3);

        // multiplier bit patterns
        run(  12,   60);   // b = 0011_1100 : one run of 1s
        run( -25,   85);   // b = 0101_0101 : alternating bits
        run( 100,  -86);   // b = 1010_1010 : alternating bits, negative
        run(  64,    2);   // powers of two

        // extremes
        run( 127,  127);
        run(-128,  127);
        run( 127, -128);
        run(-128, -128);
        run(-128,   -1);

        $display("-----+-------+-------+---------+----------+-------");
        if (errors == 0)
            $display("PASS: all %0d directed tests passed", tests);
        else
            $display("FAILED: %0d / %0d directed tests failed", errors, tests);
        $finish;
    end

endmodule

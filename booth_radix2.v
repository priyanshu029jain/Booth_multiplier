// ============================================================================
// Radix-2 Booth Multiplier - signed, parameterized, combinational
// ----------------------------------------------------------------------------
//   P = A * B   (two's complement, N-bit x N-bit -> 2N-bit)
//
//   The multiplier B is scanned in overlapping 2-bit pairs
//   {b[i], b[i-1]} (b[-1] = 0), each selecting a digit in {-1, 0, +1}.
//   Runs of 1s in B are replaced by one subtraction at the start of the
//   run and one addition after its end. N partial products are generated.
//
//   b[i] b[i-1] | digit | partial product
//   ------------+-------+----------------
//    0     0    |   0   |   0
//    0     1    |  +1   |  +A
//    1     0    |  -1   |  -A
//    1     1    |   0   |   0
// ============================================================================
`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// Booth encoder: one 2-bit pair -> control signals
// ----------------------------------------------------------------------------
module booth2_encoder (
    input  wire [1:0] pair,  // {b[i], b[i-1]}
    output wire       one,   // |digit| == 1
    output wire       neg    // digit is negative
);
    assign one = pair[1] ^ pair[0];
    assign neg = pair[1];
endmodule

// ----------------------------------------------------------------------------
// Partial product generator: selects 0 / A and negates if required
// ----------------------------------------------------------------------------
module booth2_pp_gen #(
    parameter W = 16                 // width of partial product (2N)
) (
    input  wire [W-1:0] a_ext,       // multiplicand, sign-extended to W bits
    input  wire         one,
    input  wire         neg,
    output wire [W-1:0] pp
);
    wire [W-1:0] mag = one ? a_ext : {W{1'b0}};

    // two's complement negation: ~mag + 1
    assign pp = neg ? (~mag + {{(W-1){1'b0}}, 1'b1}) : mag;
endmodule

// ----------------------------------------------------------------------------
// Top level
// ----------------------------------------------------------------------------
module booth_radix2 #(
    parameter N = 8                  // operand width (any N >= 2)
) (
    input  wire signed [N-1:0]   a,  // multiplicand
    input  wire signed [N-1:0]   b,  // multiplier
    output wire signed [2*N-1:0] p   // product
);
    localparam W = 2 * N;            // product width

    // Multiplicand sign-extended to product width
    wire [W-1:0] a_ext = {{N{a[N-1]}}, a};

    // Multiplier with implicit b[-1] = 0
    wire [N:0] b_ext = {b, 1'b0};

    // Shifted partial products, flattened
    wire [W*N-1:0] pp_bus;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_pp
            wire         one, neg;
            wire [W-1:0] pp;

            booth2_encoder u_enc (
                .pair (b_ext[i+1 : i]),
                .one  (one),
                .neg  (neg)
            );

            booth2_pp_gen #(.W(W)) u_pp (
                .a_ext (a_ext),
                .one   (one),
                .neg   (neg),
                .pp    (pp)
            );

            // weight of pair i is 2^i -> shift left by i
            assign pp_bus[W*i +: W] = pp << i;
        end
    endgenerate

    // Partial product accumulation (synthesis maps this to an adder tree)
    reg [W-1:0] sum;
    integer k;
    always @(*) begin
        sum = {W{1'b0}};
        for (k = 0; k < N; k = k + 1)
            sum = sum + pp_bus[W*k +: W];
    end

    assign p = sum;
endmodule

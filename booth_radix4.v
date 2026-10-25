// ============================================================================
// Radix-4 (Modified) Booth Multiplier - signed, parameterized, combinational
// ----------------------------------------------------------------------------
//   P = A * B   (two's complement, N-bit x N-bit -> 2N-bit)
//
//   The multiplier B is recoded in overlapping 3-bit groups
//   {b[2i+1], b[2i], b[2i-1]} (b[-1] = 0), each selecting a digit in
//   {-2, -1, 0, +1, +2}. This halves the number of partial products
//   compared to a plain array multiplier (ceil(N/2) instead of N).
//
//   b[2i+1] b[2i] b[2i-1] | digit | partial product
//   ----------------------+-------+----------------
//      0      0      0    |   0   |   0
//      0      0      1    |  +1   |  +A
//      0      1      0    |  +1   |  +A
//      0      1      1    |  +2   |  +2A
//      1      0      0    |  -2   |  -2A
//      1      0      1    |  -1   |  -A
//      1      1      0    |  -1   |  -A
//      1      1      1    |   0   |   0
// ============================================================================
`timescale 1ns / 1ps

// ----------------------------------------------------------------------------
// Booth encoder: one 3-bit group -> control signals
// ----------------------------------------------------------------------------
module booth_encoder (
    input  wire [2:0] grp,   // {b[2i+1], b[2i], b[2i-1]}
    output wire       one,   // |digit| == 1
    output wire       two,   // |digit| == 2
    output wire       neg    // digit is negative
);
    assign one = grp[1] ^ grp[0];
    assign two = ( grp[2] & ~grp[1] & ~grp[0]) |
                 (~grp[2] &  grp[1] &  grp[0]);
    assign neg = grp[2];
endmodule

// ----------------------------------------------------------------------------
// Partial product generator: selects 0 / A / 2A and negates if required
// ----------------------------------------------------------------------------
module booth_pp_gen #(
    parameter W = 16                 // width of partial product (2N)
) (
    input  wire [W-1:0] a_ext,       // multiplicand, sign-extended to W bits
    input  wire         one,
    input  wire         two,
    input  wire         neg,
    output wire [W-1:0] pp
);
    wire [W-1:0] mag = one ? a_ext :
                       two ? {a_ext[W-2:0], 1'b0} :
                             {W{1'b0}};

    // two's complement negation: ~mag + 1
    assign pp = neg ? (~mag + {{(W-1){1'b0}}, 1'b1}) : mag;
endmodule

// ----------------------------------------------------------------------------
// Top level
// ----------------------------------------------------------------------------
module booth_radix4 #(
    parameter N = 8                  // operand width (any N >= 2)
) (
    input  wire signed [N-1:0]   a,  // multiplicand
    input  wire signed [N-1:0]   b,  // multiplier
    output wire signed [2*N-1:0] p   // product
);
    localparam W   = 2 * N;          // product width
    localparam M   = N + (N % 2);    // multiplier width rounded up to even
    localparam NPP = M / 2;          // number of partial products

    // Multiplicand sign-extended to product width
    wire [W-1:0] a_ext = {{N{a[N-1]}}, a};

    // Multiplier sign-extended to even width, with implicit b[-1] = 0
    wire [M:0] b_ext = {{(M-N){b[N-1]}}, b, 1'b0};

    // Shifted partial products, flattened
    wire [W*NPP-1:0] pp_bus;

    genvar i;
    generate
        for (i = 0; i < NPP; i = i + 1) begin : g_pp
            wire         one, two, neg;
            wire [W-1:0] pp;

            booth_encoder u_enc (
                .grp (b_ext[2*i+2 : 2*i]),
                .one (one),
                .two (two),
                .neg (neg)
            );

            booth_pp_gen #(.W(W)) u_pp (
                .a_ext (a_ext),
                .one   (one),
                .two   (two),
                .neg   (neg),
                .pp    (pp)
            );

            // weight of group i is 4^i -> shift left by 2i
            assign pp_bus[W*i +: W] = pp << (2*i);
        end
    endgenerate

    // Partial product accumulation (synthesis maps this to an adder tree)
    reg [W-1:0] sum;
    integer k;
    always @(*) begin
        sum = {W{1'b0}};
        for (k = 0; k < NPP; k = k + 1)
            sum = sum + pp_bus[W*k +: W];
    end

    assign p = sum;
endmodule

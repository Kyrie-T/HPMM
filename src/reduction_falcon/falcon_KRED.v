`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: tanx
// 
// Create Date: 02/06/2026
// Design Name: 
// Module Name: Falcon K-RED modular multiplication
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: K-RED design for Falcon parameter q = 12289 = 3 * 2^12 + 1
//              Adapted from Kyber's butterfly_best_KRED design
//              
// Algorithm: For q = 3 * 2^n + 1 where n=12, k=3
//   Step 1: LUT6 reduces 28-bit product to ~23-bit
//   Step 2: K-reduction: N_high - 3*N_low (split at bit 12)
//   Step 3: Conditional add q for negative results
//
// Note: Output includes implicit factor of -k = -3, which should be
//       absorbed into twiddle factor precomputation: W' = W * (-3)^(-1) mod q
//       where (-3)^(-1) mod 12289 = 8193
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module falcon_KRED(
    input clk,
    input [13:0] a,           // 14-bit input (0 to 12288)
    input [13:0] b,           // 14-bit input (0 to 12288)
    output [13:0] c_mod_q     // 14-bit output (0 to 12288)
    );
    
// Falcon parameters
localparam Q = 14'd12289;     // q = 12289 = 3 * 2^12 + 1
localparam K = 3;             // k = 3
localparam N = 12;            // n = 12

//=============================================================================
// Stage 0: Multiplication (1 cycle latency)
//=============================================================================
reg [27:0] high_reg;          // 14*14 = 28-bit product
always @(posedge clk) begin
    high_reg <= a * b;
end

//=============================================================================
// Stage 1: LUT6-based reduction of top 6 bits (1 cycle latency)
// Computes: (high_reg[27:22] << 22) mod 12289
// Then adds to low 22 bits: LUT_reduced = high_reg[21:0] + LUT_out
// Result range: 0 to 4,194,303 + 12,288 = 4,206,591 (23 bits)
//=============================================================================

// LUT6 initialization function for Falcon
// Computes bit [LUT_index] of ((i << 22) mod 12289) for all i in 0..63
function [63:0] LUT_parameter_falcon;
    input [3:0] LUT_index;
    integer i;
    integer full_output;
    begin
        for (i = 0; i < 64; i = i + 1) begin
            // (i << 22) mod 12289
            full_output = (i << 22) % 12289;
            LUT_parameter_falcon[i] = full_output[LUT_index];
        end
    end
endfunction

wire [13:0] LUT_out;          // 14-bit LUT output (max 12288)

generate
    genvar i;
    for (i = 0; i < 14; i = i + 1) begin: LUTS
        LUT6 #(
            .INIT(LUT_parameter_falcon(i))  // Specify LUT Contents
        ) LUT6_inst (
            .O(LUT_out[i]),       // LUT general output
            .I0(high_reg[22]),    // LUT input - bit 22
            .I1(high_reg[23]),    // LUT input - bit 23
            .I2(high_reg[24]),    // LUT input - bit 24
            .I3(high_reg[25]),    // LUT input - bit 25
            .I4(high_reg[26]),    // LUT input - bit 26
            .I5(high_reg[27])     // LUT input - bit 27
        );
    end
endgenerate

wire [22:0] LUT_reduced;
assign LUT_reduced = high_reg[21:0] + LUT_out;

reg [22:0] LUT_reduced_reg;
always @(posedge clk) begin
    LUT_reduced_reg <= LUT_reduced;
end

//=============================================================================
// Stage 2: K-reduction (1 cycle latency)
// Split at bit n=12: N_high = L[22:12], N_low = L[11:0]
// Compute: Kred_result = N_high - 3 * N_low
// 
// Mathematical basis: 2^12 ≡ -3 (mod 12289)
// So: N = N_high * 2^12 + N_low ≡ -3 * N_high + N_low (mod q)
// We compute: N_high - 3 * N_low which equals -3 * N (mod q)
//
// N_high range: 0 to 2047 (11 bits from [22:12])
// N_low range: 0 to 4095 (12 bits from [11:0])
// 3 * N_low range: 0 to 12285
// Kred_result range: -12285 to 2047
//=============================================================================

wire [10:0] Kred_N_high;                    // L[22:12], 11 bits
wire [11:0] Kred_N_low;                     // L[11:0], 12 bits
wire [13:0] three_N_low;                    // 3 * N_low, max 12285, 14 bits

assign Kred_N_high = LUT_reduced_reg[22:12];
assign Kred_N_low = LUT_reduced_reg[11:0];

// 3 * N_low = 2 * N_low + N_low (only one shift + one add)
assign three_N_low = {Kred_N_low, 1'b0} + {2'b0, Kred_N_low};

wire signed [14:0] Kred_result;             // Signed result, 15 bits
assign Kred_result = {4'b0, Kred_N_high} - {1'b0, three_N_low};

reg signed [14:0] Kred_result_reg;
always @(posedge clk) begin
    Kred_result_reg <= Kred_result;
end

//=============================================================================
// Stage 3: Final correction (combinational)
// If result is negative, add q to bring it into [0, q-1]
// Range after correction: [0, 12288]
//=============================================================================

wire [14:0] plus_or_zero_q;
// If negative (MSB = 1), add q = 12289
assign plus_or_zero_q = (Kred_result_reg[14]) ? 15'd12289 : 15'd0;

wire [14:0] corrected_result;
assign corrected_result = Kred_result_reg + plus_or_zero_q;

// Final output (14 bits)
assign c_mod_q = corrected_result[13:0];

endmodule

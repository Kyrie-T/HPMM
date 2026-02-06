`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: tanx
// 
// Create Date: 02/06/2026
// Design Name: 
// Module Name: falcon_KRED_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for Falcon K-RED modular multiplication
//              Tests the falcon_KRED module for correctness
//              
// Important: The K-RED algorithm computes (-3 * a * b) mod q, not (a * b) mod q
//            The factor -3 should be absorbed into twiddle factor precomputation
//
// Verification: For each test, we verify:
//               DUT_output ≡ -3 * a * b (mod 12289)
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Fixed pipeline alignment issues
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module falcon_KRED_tb();

// Parameters
localparam Q = 12289;           // Falcon modulus
localparam K = 3;               // K factor in K-RED
localparam WIDTH = 14;          // Bit width for Falcon
localparam CLK_PERIOD = 10;     // Clock period in ns
localparam PIPELINE_DEPTH = 2;  // DUT pipeline depth (3 register stages + 1 for input capture)

// Testbench parameters
localparam NUM_RANDOM_TESTS = 100000;   // Number of random tests
localparam NUM_EDGE_TESTS = 1000;       // Edge case tests per category

// Signals
reg clk;
reg [WIDTH-1:0] a, b;
wire [WIDTH-1:0] c_mod_q;

// Pipeline registers for expected value comparison
// Need PIPELINE_DEPTH+1 stages due to timing
reg [WIDTH-1:0] a_pipe [0:PIPELINE_DEPTH];
reg [WIDTH-1:0] b_pipe [0:PIPELINE_DEPTH];

// Test counters
integer pass_count;
integer fail_count;
integer total_tests;
integer test_phase;
integer pipe_idx;
integer skip_count;

// Random seed
integer seed;

// Instantiate DUT
falcon_KRED DUT (
    .clk(clk),
    .a(a),
    .b(b),
    .c_mod_q(c_mod_q)
);

// Clock generation
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// Pipeline delay for input tracking
always @(posedge clk) begin
    a_pipe[0] <= a;
    b_pipe[0] <= b;
    for (pipe_idx = 1; pipe_idx <= PIPELINE_DEPTH; pipe_idx = pipe_idx + 1) begin
        a_pipe[pipe_idx] <= a_pipe[pipe_idx-1];
        b_pipe[pipe_idx] <= b_pipe[pipe_idx-1];
    end
end

// Function to compute expected result: (-3 * a * b) mod q
function [WIDTH-1:0] expected_result;
    input [WIDTH-1:0] in_a;
    input [WIDTH-1:0] in_b;
    reg [31:0] product;
    reg [31:0] product_k;
    begin
        product = in_a * in_b;
        product_k = (K * product) % Q;
        // (-K * a * b) mod q = (q - (K*a*b mod q)) mod q
        if (product_k == 0)
            expected_result = 0;
        else
            expected_result = Q - product_k;
    end
endfunction

// Function to compute standard modmul: (a * b) mod q
function [WIDTH-1:0] standard_modmul;
    input [WIDTH-1:0] in_a;
    input [WIDTH-1:0] in_b;
    reg [31:0] product;
    begin
        product = in_a * in_b;
        standard_modmul = product % Q;
    end
endfunction

// Verification task - use delayed inputs
task verify_result;
    reg [WIDTH-1:0] test_a;
    reg [WIDTH-1:0] test_b;
    reg [WIDTH-1:0] expected;
    begin
        // Read from the correct pipeline stage
        test_a = a_pipe[PIPELINE_DEPTH];
        test_b = b_pipe[PIPELINE_DEPTH];
        expected = expected_result(test_a, test_b);
        
        if (c_mod_q == expected) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
            if (fail_count <= 20) begin
                $display("FAIL: a=%d, b=%d | DUT=%d, Expected=%d (standard modmul=%d)",
                         test_a, test_b, c_mod_q, expected, standard_modmul(test_a, test_b));
            end
        end
        total_tests = total_tests + 1;
    end
endtask

// Task to wait for pipeline to fill and then verify
task run_test_with_pipeline;
    input [WIDTH-1:0] test_a;
    input [WIDTH-1:0] test_b;
    begin
        a = test_a;
        b = test_b;
        @(posedge clk);
        #1; // Small delay to ensure NBA completes
    end
endtask

// Main test sequence
initial begin
    $display("========================================================");
    $display("Falcon K-RED Testbench");
    $display("q = %d = %d * 2^12 + 1", Q, K);
    $display("Testing: output %d * a * b (mod %d)", -K, Q);
    $display("Pipeline depth: %d cycles (3 register stages + 1 input capture)", PIPELINE_DEPTH);
    $display("========================================================");
    
    // Initialize
    a = 0;
    b = 0;
    pass_count = 0;
    fail_count = 0;
    total_tests = 0;
    seed = 12345;
    
    // Initialize pipeline registers
    for (pipe_idx = 0; pipe_idx <= PIPELINE_DEPTH; pipe_idx = pipe_idx + 1) begin
        a_pipe[pipe_idx] = 0;
        b_pipe[pipe_idx] = 0;
    end
    
    // Wait for reset and fill pipeline with zeros
    repeat(10) @(posedge clk);
    #1;
    
    //=========================================================================
    // Phase 1: Edge case tests
    //=========================================================================
    $display("\n[Phase 1] Edge Case Tests...");
    test_phase = 1;
    
    // Test a=0
    $display("  Testing a=0...");
    a = 0;
    skip_count = 0;
    for (b = 0; b < NUM_EDGE_TESTS && b < Q; b = b + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test b=0
    $display("  Testing b=0...");
    b = 0;
    skip_count = 0;
    for (a = 0; a < NUM_EDGE_TESTS && a < Q; a = a + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test a=1
    $display("  Testing a=1...");
    a = 1;
    skip_count = 0;
    for (b = 0; b < NUM_EDGE_TESTS && b < Q; b = b + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test b=1
    $display("  Testing b=1...");
    b = 1;
    skip_count = 0;
    for (a = 0; a < NUM_EDGE_TESTS && a < Q; a = a + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test a=q-1
    $display("  Testing a=q-1=%d...", Q-1);
    a = Q - 1;
    skip_count = 0;
    for (b = 0; b < NUM_EDGE_TESTS && b < Q; b = b + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test b=q-1
    $display("  Testing b=q-1=%d...", Q-1);
    b = Q - 1;
    skip_count = 0;
    for (a = 0; a < NUM_EDGE_TESTS && a < Q; a = a + 1) begin
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test a=b (squares)
    $display("  Testing squares a=b...");
    skip_count = 0;
    for (a = 0; a < NUM_EDGE_TESTS && a < Q; a = a + 1) begin
        b = a;
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    $display("  Phase 1 complete: %d passed, %d failed", pass_count, fail_count);
    
    //=========================================================================
    // Phase 2: Power-of-2 boundary tests
    //=========================================================================
    $display("\n[Phase 2] Power-of-2 Boundary Tests...");
    test_phase = 2;
    
    // Test around 2^12 = 4096 boundary
    $display("  Testing around 2^12 boundary...");
    skip_count = 0;
    for (a = 4090; a < 4102 && a < Q; a = a + 1) begin
        for (b = 4090; b < 4102 && b < Q; b = b + 1) begin
            @(posedge clk);
            #1;
            skip_count = skip_count + 1;
            if (skip_count > PIPELINE_DEPTH) verify_result();
        end
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    // Test around 2^10 boundary
    $display("  Testing around 2^10 boundary...");
    skip_count = 0;
    for (a = 1020; a < 1028 && a < Q; a = a + 1) begin
        for (b = 1020; b < 1028 && b < Q; b = b + 1) begin
            @(posedge clk);
            #1;
            skip_count = skip_count + 1;
            if (skip_count > PIPELINE_DEPTH) verify_result();
        end
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    $display("  Phase 2 complete: %d passed, %d failed", pass_count, fail_count);
    
    //=========================================================================
    // Phase 3: Random tests
    //=========================================================================
    $display("\n[Phase 3] Random Tests (%d iterations)...", NUM_RANDOM_TESTS);
    test_phase = 3;
    
    skip_count = 0;
    repeat(NUM_RANDOM_TESTS) begin
        a = $random(seed) % Q;
        b = $random(seed) % Q;
        @(posedge clk);
        #1;
        skip_count = skip_count + 1;
        if (skip_count > PIPELINE_DEPTH) verify_result();
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    $display("  Phase 3 complete: %d passed, %d failed", pass_count, fail_count);
    
    //=========================================================================
    // Phase 4: Exhaustive small range test
    //=========================================================================
    $display("\n[Phase 4] Exhaustive Test (small range 0-255)...");
    test_phase = 4;
    
    skip_count = 0;
    for (a = 0; a < 256; a = a + 1) begin
        for (b = 0; b < 256; b = b + 1) begin
            @(posedge clk);
            #1;
            skip_count = skip_count + 1;
            if (skip_count > PIPELINE_DEPTH) verify_result();
        end
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    $display("  Phase 4 complete: %d passed, %d failed", pass_count, fail_count);
    
    //=========================================================================
    // Phase 5: Large value tests (near q)
    //=========================================================================
    $display("\n[Phase 5] Large Value Tests (near q)...");
    test_phase = 5;
    
    skip_count = 0;
    for (a = Q - 256; a < Q; a = a + 1) begin
        for (b = Q - 256; b < Q; b = b + 1) begin
            @(posedge clk);
            #1;
            skip_count = skip_count + 1;
            if (skip_count > PIPELINE_DEPTH) verify_result();
        end
    end
    
    // Flush pipeline
    repeat(PIPELINE_DEPTH + 2) begin
        @(posedge clk);
        #1;
        verify_result();
    end
    
    $display("  Phase 5 complete: %d passed, %d failed", pass_count, fail_count);
    
    //=========================================================================
    // Final Report
    //=========================================================================
    $display("\n========================================================");
    $display("FINAL RESULTS");
    $display("========================================================");
    $display("Total Tests:  %d", total_tests);
    $display("Passed:       %d", pass_count);
    $display("Failed:       %d", fail_count);
    $display("Pass Rate:    %.2f%%", 100.0 * pass_count / total_tests);
    
    if (fail_count == 0) begin
        $display("\n*** ALL TESTS PASSED! ***");
        $display("The falcon_KRED module correctly computes (-3 * a * b) mod 12289");
        $display("\nNote: To get standard (a*b mod q) result, pre-multiply twiddle");
        $display("factors by (-3)^(-1) mod 12289 = 4096");
    end else begin
        $display("\n*** SOME TESTS FAILED! ***");
        $display("Please review the implementation.");
    end
    
    $display("========================================================\n");
    
    $stop;
end

// Timeout watchdog
initial begin
    #500000000; // 500ms timeout
    $display("ERROR: Testbench timeout!");
    $stop;
end

endmodule

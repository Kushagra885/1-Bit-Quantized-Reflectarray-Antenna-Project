// ===============================================================
// Testbench for the Phase Calculator

// This testbench is configured with corrected input values that
// match the MATLAB GUI to produce the expected concentric ring pattern.
// ===============================================================
module tb_phase_calculator;

    // Parameters derived from the MATLAB GUI screenshot
    localparam ARRAY_DIAMETER  = 80; // 100 mm
    localparam ELEMENT_SPACING = 5;   // 5 mm, unit cell dimension
    localparam MAP_SIZE        = ARRAY_DIAMETER / ELEMENT_SPACING;

    reg clk=0;
    reg rst;
    reg start;

    // Inputs to the DUT (Device Under Test)
    reg  [63:0] k0_fix;      // Wavenumber (rad/mm)
    reg  [63:0] x_cor_fix;   // Feed X-coordinate
    reg  [63:0] y_cor_fix;   // Feed Y-coordinate
    reg  [63:0] z_cor_fix;   // Feed Z-coordinate
    reg  [63:0] the_dir_deg; // Beam Elevation Angle (theta)
    reg  [63:0] phi_dir_deg; // Beam Azimuth Angle (phi)

    // Outputs from the DUT
    wire done;
    wire [MAP_SIZE*MAP_SIZE-1:0] phase_map_flat;

    // Instantiate the phase_calculator module
    phase_calculator #(
        .ARRAY_DIAMETER(ARRAY_DIAMETER),
        .ELEMENT_SPACING(ELEMENT_SPACING)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .k0_bits(k0_fix),
        .x_cor_bits(x_cor_fix),
        .y_cor_bits(y_cor_fix),
        .z_cor_bits(z_cor_fix),
        .the_dir_deg_bits(the_dir_deg),
        .phi_dir_deg_bits(phi_dir_deg),
        .done(done),
        .phase_map_flat(phase_map_flat)
    );

    // Clock generator
    always #5 clk = ~clk;

    // Test sequence
  initial begin
    $dumpvars(0);
  end
    initial begin
        $display("Starting simulation with corrected values...");

        // --- CORRECTED INPUT VALUES (Q16 format) ---
        // These values now match the MATLAB GUI to generate the target output
        // Frequency = 32 GHz -> lambda = 9.375 mm -> k0 = 2*pi/lambda = 0.6702
        k0_fix      = 64'h40E572474538EF35;//h3FE572474538EF35 // 0.6702 * 2^16
        // Feed Positio from GUI: (0, 0, 170)
        x_cor_fix   = 64'h00000000; // 0
        y_cor_fix   = 64'h00000000; // 0
        z_cor_fix   = 64'h4165400000000000;//h4065400000000000 // 170 * 2^16
        // Beam Direction from GUI: Theta = 0, Phi = 0 (Broadside, points straight up)
        the_dir_deg = 64'h4056800000000000;
        phi_dir_deg = 64'd0;

        // Reset and start the process
        rst = 1; start = 0;
        #20;
        rst = 0;
        #10;
        start = 1;
        #10;
        start = 0;

        // Wait for the calculation to finish
        wait(done);
        $display("Calculation finished at time %t!", $time);
        
        // Allow time for final waveform viewing before finishing
        #10000;
        $finish;
    end
endmodule
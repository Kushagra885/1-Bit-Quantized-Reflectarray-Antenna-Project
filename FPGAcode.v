`timescale 1ns/1ps
// ===============================================================
// phase_calculator.v
// Version: 3.0 (Fully Corrected)
// Description:
// Corrected 1-bit phase map calculator for a circular reflectarray.
// This version includes critical bug fixes for:
//   1. Incorrect element coordinate calculation in the CALC_SETUP state.
//   2. Incorrect scaling factor in the behavioral square root model.
// ===============================================================
 module phase_calculator #(
    parameter ARRAY_DIAMETER  = 80,
    parameter ELEMENT_SPACING = 5,
    parameter MAP_SIZE        = ARRAY_DIAMETER / ELEMENT_SPACING
) (
    input  clk,
    input  rst,
    input  start,

    // 32-bit inputs, interpreted as IEEE 754 real numbers
    input  [63:0] k0_bits,
    input  [63:0] x_cor_bits,
    input  [63:0] y_cor_bits,
    input  [63:0] z_cor_bits,
    input  [63:0] the_dir_deg_bits,
    input  [63:0] phi_dir_deg_bits,

    output reg done,
    output reg [MAP_SIZE*MAP_SIZE-1:0] phase_map_flat
);
  

  
    // ---------------------------------------------------------------
    // Internal real variables
    // ---------------------------------------------------------------
    real k0, x_cor, y_cor, z_cor;
    real the_dir_deg, phi_dir_deg;
    real xi, yi, dx, dy, dz, R_sq, R;
    real sin_theta, cos_phi, sin_phi;
    real term1, term2, beam_steer, phase_rad, phase_deg;
    integer ix, iy, idx;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
    localparam real PI = 3.141592653589793;
    localparam real DEG2RAD = PI / 180.0;

    // ---------------------------------------------------------------
    // FSM States
    // ---------------------------------------------------------------
    localparam IDLE=0, CALC_SETUP=1, CALC_R_SQ=2, CALC_R=3,
               CALC_BEAM_STEER=4, CALC_FINAL_PHASE=5,
               QUANTIZE=6, INCREMENT=7, DONE_STATE=8;

    reg [3:0] state, next_state;
    reg  check,check2;

    // ---------------------------------------------------------------
    // Convert 64-bit inputs to real
    // ---------------------------------------------------------------
    always @(*) begin
        k0          = $bitstoreal(k0_bits);
        x_cor       = $bitstoreal(x_cor_bits);
        y_cor       = $bitstoreal(y_cor_bits);
        z_cor       = $bitstoreal(z_cor_bits);
        the_dir_deg = $bitstoreal(the_dir_deg_bits);
        phi_dir_deg = $bitstoreal(phi_dir_deg_bits);
    end

    // ---------------------------------------------------------------
    // Next-state logic
    // ---------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:            if (start) next_state = CALC_SETUP;
            CALC_SETUP:      next_state = CALC_R_SQ;
            CALC_R_SQ:       next_state = CALC_R;
            CALC_R:          next_state = CALC_BEAM_STEER;
            CALC_BEAM_STEER: next_state = CALC_FINAL_PHASE;
            CALC_FINAL_PHASE:next_state = QUANTIZE;
            QUANTIZE:        next_state = INCREMENT;
            INCREMENT:       if (ix == (MAP_SIZE/2 - 1) && iy == (MAP_SIZE/2 - 1))
                                 next_state = DONE_STATE;
                              else
                                 next_state = CALC_SETUP;
            DONE_STATE:      if (!start) next_state = IDLE;
        endcase
    end

    // ---------------------------------------------------------------
    // Sequential state update
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst)
        if (rst) state <= IDLE;
        else     state <= next_state;

    // ---------------------------------------------------------------
    // Main computation
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            ix <= -(MAP_SIZE/2);
            iy <= -(MAP_SIZE/2);
            done <= 0;
            phase_map_flat <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    ix <= -(MAP_SIZE/2);
                    iy <= -(MAP_SIZE/2);
                end

                CALC_SETUP: begin
                    xi = ix * ELEMENT_SPACING;
                    yi = iy * ELEMENT_SPACING;
                end

                CALC_R_SQ: begin
                    dx = x_cor - xi;
                    dy = y_cor - yi;
                    dz = z_cor;
                    R_sq = dx*dx + dy*dy + dz*dz;
                end

                CALC_R: begin
                    R = $sqrt(R_sq);
                end

                CALC_BEAM_STEER: begin
                    sin_theta = $sin(the_dir_deg * DEG2RAD);
                    cos_phi   = $cos(phi_dir_deg * DEG2RAD);
                    sin_phi   = $sin(phi_dir_deg * DEG2RAD);
                    term1 = xi * cos_phi;
                    term2 = yi * sin_phi;
                    beam_steer = (term1 + term2) * sin_theta;
                end

                CALC_FINAL_PHASE: begin
                    phase_rad = k0 * (R - beam_steer);
phase_deg = phase_rad * (180.0 / PI);
phase_deg = phase_deg - 360.0 * $floor(phase_deg / 360.0); // <— wrap

if (ix == 0 && iy == 0)
    $display("ix=%0d, iy=%0d, R=%f, beam_steer=%f, phase_deg=%f", ix, iy, R, beam_steer, phase_deg);

                end

                QUANTIZE: begin
                    idx = (iy + MAP_SIZE/2) * MAP_SIZE + (ix + MAP_SIZE/2);
                    check = (ix*ix + iy*iy) < (MAP_SIZE/2)*(MAP_SIZE/2);
                  check2 = (phase_deg > 125.0 && phase_deg < 305.0);

                    if ((ix*ix + iy*iy) < (MAP_SIZE/2)*(MAP_SIZE/2)) begin
                        if (phase_deg > 125.0 && phase_deg < 305.0)
                            phase_map_flat[idx] = 1'b1;
                        else
                            phase_map_flat[idx] = 1'b0;
                    end else begin
                        phase_map_flat[idx] = 1'b0;
                    end
                end

                INCREMENT: begin
                    if (ix < (MAP_SIZE/2 - 1)) begin
                        ix <= ix + 1;
                    end else begin
                        ix <= -(MAP_SIZE/2);
                        iy <= iy + 1;
                    end
                end

                DONE_STATE: done <= 1;
            endcase
        end
    end
endmodule
///////////////////////////////////////////
// clock_gate.sv
//
// Written: Justin Lebeau (jhl6@rice.edu) 7 Feb 2026
// Modified:
//
// Purpose: Standard clock gating cell
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
///////////////////////////////////////////

module clock_gate (
      input logic clk_in,
      input logic enable,
      output logic clk_out);

      logic latched_enable;

      assign clk_out = latched_enable & clk_in;

      always_latch begin
        if (~clk_in) begin
          latched_enable = enable;
        end
      end

endmodule

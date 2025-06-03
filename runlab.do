# Create work library
vlib work

# Compile Verilog
#     All Verilog files that are part of this design should have
#     their own "vlog" line below.
vlog "./alpha.sv"
vlog "./montcios.sv"
vlog "./testbench.sv"
vlog "./alpha_f.sv"
vlog "./beta.sv"
vlog "./gamma.sv"
vlog "./gamma_f.sv"
vlog "./alpha_block.sv"
vlog "./gamma_block.sv"
vlog "./ciosrow.sv"

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the
#     testbench module you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work testbench

# Source the wave do file
#     This should be the file that sets up the signal window for
#     the module you are testing.
do wave.do

# Set the window types
view wave
view structure
view signals

# Run the simulation
run -all

# End

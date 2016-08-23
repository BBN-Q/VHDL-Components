# VHDL-Components
Reusable components for FPGA firmware written VHDL and mainly targeting Xilinx FPGAs.

#Components

## DelayLine
A variable tap and variable width delay line.

## Synchronizer
A single bit N-flip-flop synchronizer with timing constraints for Vivado 

##UpCounter/Downcounter
Variable-width up and down counters with load and enable.  Implemented with a mux/select for improved timing.

## ComplexMultipler
Fully pipelined complex AXI stream multiplier with generic widths

## PolyphaseSSB
Apply single-sideband modulation to a 4-sample-wide complex data stream.

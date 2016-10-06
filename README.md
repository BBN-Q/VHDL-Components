# VHDL-Components
Reusable components for FPGA firmware written VHDL and mainly targeting Xilinx FPGAs.

#Components

## DelayLine

A variable tap and variable width delay line.

## Synchronizer

A single bit N-flip-flop synchronizer with timing constraints for Vivado

##UpCounter/Downcounter

Variable-width up and down counters with load and enable.  Implemented with a
mux/select for improved timing.

## ComplexMultipler

Fully pipelined complex AXI stream multiplier with generic widths

## PolyphaseSSB

Apply single-sideband modulation to a 4-sample-wide complex data stream.

## AXI_CSR

Python module to create an AXI CSR register module from a jinja2 template. After
importing the module, create an iterable of `Register` objects and then call
`write_axi_csr` to create the source file. E.g.

```python
registers = [
	Register(0, "status1", "read"),
	Register(1, "status2", "read"),
	Register(2, "control1", "write", initial_value=0xffffffff),
	Register(3, "control2", "write", initial_value=0x01234567),
	Register(5, "scratch", "internal", initial_value=0x000dba11)
]

write_axi_csr("AXI_CSR.vhd", registers, 32)
```

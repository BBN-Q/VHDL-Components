-- Simple sin/cos LUT
-- Full size for minimal latency
--
-- Original author Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity SinCosLUT is
	generic (
		PHASE_WIDTH : natural := 14;
		OUTPUT_WIDTH : natural := 14
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		phase_tdata  : in std_logic_vector(PHASE_WIDTH-1 downto 0);
		phase_tvalid : in std_logic;

		sin_tdata     : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
		cos_tdata     : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
		sincos_tvalid : out std_logic
	);
end entity;

architecture arch of SinCosLUT is

	constant LUT_SIZE : natural := 2**(PHASE_WIDTH);
	type lut_array_t is array(LUT_SIZE-1 downto 0) of std_logic_vector(OUTPUT_WIDTH-1 downto 0);
	function fill_lut return lut_array_t is
		variable lut : lut_array_t;
		variable tmp : integer;
	begin
		for ct in 0 to LUT_SIZE-1 loop
			tmp := integer( (real(2**OUTPUT_WIDTH) - 1.0) * sin(2.0*MATH_PI*real(ct)/real(LUT_SIZE)) );
			lut(ct) := std_logic_vector(to_signed(tmp, OUTPUT_WIDTH));
		end loop;
		return lut;
	end function;

	--seems this should be constant but then rom_style requires signal
	signal lut : lut_array_t := fill_lut;
	attribute rom_style : string;
	attribute rom_style of lut : signal is "block";

	signal mem_data_sin, mem_data_cos : std_logic_vector(OUTPUT_WIDTH-1 downto 0);

begin

	sin_port : process(clk)
		variable sin_addr : natural range 0 to 2**PHASE_WIDTH-1;
	begin
		if rising_edge(clk) then
			sin_addr := to_integer(unsigned(phase_tdata));
			sin_tdata <= lut(sin_addr);
		end if;
	end process;

	cos_port : process(clk)
		variable cos_addr : natural range 0 to 2**PHASE_WIDTH-1;
		variable cos_quarter_shift : std_logic_vector(1 downto 0);
		variable cos_addr_slv : std_logic_vector(PHASE_WIDTH-1 downto 0);
	begin
		if rising_edge(clk) then
			cos_quarter_shift := std_logic_vector(to_unsigned(1, 2) + unsigned(phase_tdata(phase_tdata'high downto phase_tdata'high-1)));
			--Vivado can't infer & operands if done in line
			cos_addr_slv := cos_quarter_shift & phase_tdata(phase_tdata'high-2 downto 0);
			cos_addr := to_integer(unsigned(cos_addr_slv));
			cos_tdata <= lut(cos_addr);
		end if;
	end process;


end architecture;

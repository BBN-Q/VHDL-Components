-- Simple sin/cos LUT
-- Register input/output to allow usual quarter-wave symmetry
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

	--0 to pi/2 sin look up table
	constant LUT_SIZE : natural := 2**(PHASE_WIDTH-2);
	type lut_array is array(LUT_SIZE-1 downto 0) of signed(OUTPUT_WIDTH-1 downto 0);
	function fill_lut return lut_array is
		variable lut : lut_array;
		variable tmp : integer;
		constant SCALE : real := real(2**(OUTPUT_WIDTH-1)) - 1.0;
	begin
		for ct in 0 to LUT_SIZE-1 loop
			tmp := integer( SCALE * sin((MATH_PI/2.0)*real(ct)/real(LUT_SIZE)) );
			lut(ct) := to_signed(tmp, OUTPUT_WIDTH);
		end loop;
		return lut;
	end function;

	--seems this should be constant but then rom_style requires signal
	signal lut : lut_array := fill_lut;
	attribute rom_style : string;
	attribute rom_style of lut : signal is "block";

	signal sin_addr, cos_addr : natural range 0 to 2**(PHASE_WIDTH-2)-1;
	subtype ADDR_SLICE is natural range PHASE_WIDTH-3 downto 0;

	signal sin_tdata_reg, cos_tdata_reg : signed(OUTPUT_WIDTH-1 downto 0);

	signal sign_bit : std_logic;
	signal ones_complement_addr_bit : std_logic;
	signal sin_sign_bit_d : std_logic := '0';
	signal cos_sign_bit, cos_sign_bit_d : std_logic := '0';

begin

	sign_bit <= phase_tdata(phase_tdata'high);
	ones_complement_addr_bit <= phase_tdata(phase_tdata'high - 1);

	sin_port : process(clk)
		variable lut_data : signed(OUTPUT_WIDTH-1 downto 0);
	begin
		if rising_edge(clk) then

			--register addr with possible ones complement
			if ones_complement_addr_bit = '0' then
				sin_addr <= to_integer(unsigned(phase_tdata(ADDR_SLICE)));
			else
				sin_addr <= to_integer(unsigned(not phase_tdata(ADDR_SLICE)));
			end if;

			--Register output data from BRAM
			sin_tdata_reg <= lut_data;
			lut_data := lut(sin_addr);

		end if;
	end process;

	sin_sign_bit_delay : entity work.DelayLine
		generic map ( DELAY_TAPS => 3)
		port map( clk => clk, rst => rst, data_in(0) => sign_bit, data_out(0) => sin_sign_bit_d);

	-- should be sin_tdata <= std_logic_vector(sin_tdata_reg) when sin_sign_bit_d = '0' else std_logic_vector(-sin_tdata_reg);
	-- instead sign inversion as one's complement
	-- could be off by 1 bit but just make OUTPUT_WIDTH wider to compensate
	-- TODO: investigate skewing phase and LUT by 1/2 LSB see
	sin_tdata <= std_logic_vector(sin_tdata_reg) when sin_sign_bit_d = '0' else not std_logic_vector(sin_tdata_reg);

	-- cos(\theta) = sin(\pi/2 - \theta) = sin(\pi/2 + \theta)
	-- pi/2 shift just adds 01 to sign/address inversion bits 00 -> 01; 01 -> 10; 10 -> 11; 11 -> 11
	-- cos address inversion = not sin address inversion and cos sign inversion = sin sign inversion xor sin address inversion
	cos_port : process(clk)
		variable lut_data : signed(OUTPUT_WIDTH-1 downto 0);
	begin
		if rising_edge(clk) then
			--register addr with possible ones complement
			if ones_complement_addr_bit = '1' then
				cos_addr <= to_integer(unsigned(phase_tdata(ADDR_SLICE)));
			else
				cos_addr <= to_integer(unsigned(not phase_tdata(ADDR_SLICE)));
			end if;

			--Register output data from BRAM
			cos_tdata_reg <= lut_data;
			lut_data := lut(cos_addr);

		end if;
	end process;

	--sign inversion as ones complement
	cos_sign_bit <= sign_bit xor ones_complement_addr_bit;
	cos_sign_bit_delay : entity work.DelayLine
		generic map ( DELAY_TAPS => 3)
		port map( clk => clk, rst => rst, data_in(0) => cos_sign_bit, data_out(0) => cos_sign_bit_d);
	cos_tdata <= std_logic_vector(cos_tdata_reg) when cos_sign_bit_d = '0' else not std_logic_vector(cos_tdata_reg);

end architecture;

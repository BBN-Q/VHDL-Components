-- Simple truncating phase generator with additional 90 degree shifted output
--
-- Original author Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PhaseGenerator is
	generic (
		ACCUMULATOR_WIDTH : natural := 32;
		OUTPUT_WIDTH : natural := 16
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		phase_increment : in std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0);
		phase_offset    : in std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0);

		phase    : out std_logic_vector(OUTPUT_WIDTH-1 downto 0);
		vld      : out std_logic
	);
end entity;

architecture arch of PhaseGenerator is

	signal accum : unsigned(ACCUMULATOR_WIDTH-1 downto 0);
	signal phase_int : unsigned(ACCUMULATOR_WIDTH-1 downto 0);
	signal phase_offset_d : unsigned(ACCUMULATOR_WIDTH-1 downto 0);
begin

	--Main accumulation process
	main : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				accum    <= (others => '0');
				phase_offset_d <= (others => '0');
				phase_int    <= (others => '0');
			else
				accum        <= accum + unsigned(phase_increment);
				--register to align increment and offset updates
				phase_offset_d <= unsigned(phase_offset);
				phase_int    <= accum + phase_offset_d;
			end if;
		end if;
	end process;

	--Truncate output
	phase    <= std_logic_vector(phase_int(accum'high downto accum'high-OUTPUT_WIDTH+1));

end architecture;

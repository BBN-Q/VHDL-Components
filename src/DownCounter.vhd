----
-- Original author: Blake Johnson
-- Copyright 2015,2016 Raytheon BBN Technologies
--
-- A basic down counter.
----

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DownCounter is
	generic ( nbits : natural := 8 );
	port (
		clk : in	std_logic;
		rst : in std_logic;
		en  : in	std_logic;
		load_value : in	std_logic_vector(nbits-1 downto 0);
		load : in	std_logic;
		Q : out	std_logic_vector(nbits-1 downto 0)
	);
end DownCounter;

architecture arch of DownCounter is
	signal value : std_logic_vector(nbits-1 downto 0) := (others => '0');
begin

Q <= value;

main: process ( clk )
begin
	if rising_edge(clk) then
		if rst = '1' then
			value <= (others => '0');
		else
		 	if load = '1' then
				value <= load_value;
			elsif en = '1' then
				value <= std_logic_vector(unsigned(value) - 1);
			end if;
		end if;
	end if;
end process;

end arch;

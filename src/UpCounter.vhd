----
-- Original author: Blake Johnson
-- Copyright 2015, Raytheon BBN Technologies
--
-- A basic up counter.
----

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UpCounter is
	Generic ( nbits : integer := 8);
    Port ( clk : in  STD_LOGIC;
	       rst : in STD_LOGIC;
           en : in  STD_LOGIC;
           load_value : in  STD_LOGIC_VECTOR(nbits-1 downto 0);
           load : in  STD_LOGIC;
           Q : out  STD_LOGIC_VECTOR(nbits-1 downto 0));
end UpCounter;

architecture Behavioral of UpCounter is
	signal value : STD_LOGIC_VECTOR(nbits-1 downto 0) := (others => '0');
	signal sel : std_logic_vector(1 downto 0) := (others => '0');
begin

Q <= value;
sel <= load & en;

process (clk, rst) begin
	if rising_edge(clk) then
		if rst = '1' then
			value <= (others => '0');
		else
			case (sel) is
				when "00" =>
					value <= value;
				when "10" | "11" =>
					--load
					value <= load_value;
				when "01" =>
					value <= std_logic_vector(unsigned(value) + 1);
				when others =>
					null;
			end case;
		end if;
	end if;
end process;


end Behavioral;


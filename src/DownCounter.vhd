library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity DownCounter is
	Generic ( nbits : integer := 8);
    Port ( clk : in  STD_LOGIC;
	       rst : in STD_LOGIC;
           en : in  STD_LOGIC;
           load_value : in  STD_LOGIC_VECTOR(nbits-1 downto 0);
           load : in  STD_LOGIC;
           Q : out  STD_LOGIC_VECTOR(nbits-1 downto 0));
end DownCounter;

architecture Behavioral of DownCounter is
	signal value : STD_LOGIC_VECTOR(nbits-1 downto 0);
begin

Q <= value;

process (clk, en, load, load_value, rst) begin
	if rst = '1' then
		value <= (others => '0');
	elsif rising_edge(clk) then
		if load = '1' then
			value <= load_value;
		elsif en = '1' then
			value <= std_logic_vector(unsigned(value) - 1);
		else
			value <= value;
		end if;
	end if;
end process;


end Behavioral;
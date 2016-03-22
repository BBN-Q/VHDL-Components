-- Fake testing module that mocks a 4:1 DDR OSERDES module
--
-- Original authors Diego Riste and Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FakeOSERDES is
	generic (
		SAMPLE_WIDTH : natural := 16;
		CLK_PERIOD : time := 2 ns
	);
	port (
		reset : in std_logic;

		data_in    : in std_logic_vector(4*SAMPLE_WIDTH-1 downto 0);
		clk_in     : in std_logic;

		data_out : out std_logic_vector(SAMPLE_WIDTH-1 downto 0)
	);
end entity ; -- FakeOSERDES

architecture arch of FakeOSERDES is

begin

serialize : process
variable registered_data : std_logic_vector(4*SAMPLE_WIDTH-1 downto 0);
begin
	wait until rising_edge(clk_in);
	while true loop
		--register the input data as a crude clock crosser
		registered_data := data_in;
		if reset = '1' then
			data_out <= (others => '0');
			wait for CLK_PERIOD;
		else
			for ct in 0 to 3 loop
				data_out <= registered_data((ct+1)*SAMPLE_WIDTH-1 downto ct*SAMPLE_WIDTH);
				if ct = 3 then
					wait until rising_edge(clk_in);
				else
					wait for CLK_PERIOD/2;
				end if;
			end loop; --
		end if;
	end loop ; --
end process; -- serialize

end architecture ; -- arch

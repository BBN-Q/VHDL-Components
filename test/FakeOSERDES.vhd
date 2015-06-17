-- Fake testing module that mocks a 4:1 DDR OSERDES module
--
-- Original authors Diego Riste and Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity FakeOSERDES is
	generic (
		SAMPLE_WIDTH : natural := 16;
		FPGA_CLK_PERIOD : time := 4 ns
	);
	port (
		clk_in : in std_logic;
		reset : in std_logic;

		data_in : in std_logic_vector(4*SAMPLE_WIDTH-1 downto 0);

		data_out : out std_logic_vector(SAMPLE_WIDTH-1 downto 0);
		clk_out : buffer std_logic := '0'
	);
end entity ; -- FakeOSERDES

architecture arch of FakeOSERDES is

constant CLK_OUT_PERIOD : time := FPGA_CLK_PERIOD/2;


begin

clk_out <= not clk_out after CLK_OUT_PERIOD/2;

serialize : process
variable registered_data : std_logic_vector(4*SAMPLE_WIDTH-1 downto 0);
begin
	wait until rising_edge(clk_out);
	while true loop
		--register the input data as a crude clock crosser
		registered_data := data_in;
		if reset = '1' then
			data_out <= (others => '0');
			wait for CLK_OUT_PERIOD;
		else
			for ct in 0 to 3 loop
				data_out <= registered_data((ct+1)*SAMPLE_WIDTH-1 downto ct*SAMPLE_WIDTH);
				wait for CLK_OUT_PERIOD/2;
			end loop; --
		end if;
	end loop ; --
end process; -- serialize

end architecture ; -- arch

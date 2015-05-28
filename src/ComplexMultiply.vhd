library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

entity ComplexMultiply is
  port (
	clock : in std_logic;
	reset : in std_logic;
	data_in_A_re : in std_logic_vector(15 downto 0);
	data_in_A_im : in std_logic_vector(15 downto 0);
	data_in_B_re : in std_logic_vector(15 downto 0);
	data_in_B_im : in std_logic_vector(15 downto 0);
	data_out_re : out std_logic_vector(15 downto 0);
	data_out_im : out std_logic_vector(15 downto 0)
  ) ;
end entity ; -- ComplexMultiply

architecture arch of ComplexMultiply is

signal temp_mul1, temp_mul2, temp_mul3, temp_mul4, temp_add1, temp_add2 : signed(31 downto 0);

begin

main : process(clock)
begin
	if rising_edge(clock) then
		temp_mul1 <= signed(data_in_A_re) * signed(data_in_B_re);
		temp_mul2 <= signed(data_in_A_re) * signed(data_in_B_im);
		temp_mul3 <= signed(data_in_A_im) * signed(data_in_B_re);
		temp_mul4 <= signed(data_in_A_im) * signed(data_in_B_im);
		temp_add1 <= temp_mul1 - temp_mul4; --could be replaced by variables for shorter pipeline
		temp_add2 <= temp_mul2 + temp_mul3;
		--resize while keeping the sign bit 
		data_out_re <= std_logic_vector(resize(temp_add1(temp_add1'high downto temp_add1'high - 16), 16));
		data_out_im <= std_logic_vector(resize(temp_add2(temp_add2'high downto temp_add2'high - 16), 16));
	end if;

end process ; -- main

end architecture ; -- arch
-- Shift register delay line with synchronous reset
--
-- Original authors Colm Ryan and Blake Johnson
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;

entity DelayLine is
  generic(
    REG_WIDTH : natural := 1;
    RESET_VALUE : std_logic := '0';
    DELAY_TAPS : natural := 1
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    data_in : in std_logic_vector(REG_WIDTH-1 downto 0);
    data_out : out std_logic_vector(REG_WIDTH-1 downto 0)
  );
end entity;

architecture arch of DelayLine is

type DELAY_LINE_t is array(DELAY_TAPS-1 downto 0) of std_logic_vector(REG_WIDTH-1 downto 0);
shared variable delay_line : DELAY_LINE_t := (others => (others => RESET_VALUE));
attribute shreg_extract : string;
attribute shreg_extract of delay_line : variable is "TRUE";

begin

main : process(clk)

begin
  if rising_edge(clk) then
    if rst = '1' then
      delay_line := (others => (others => RESET_VALUE));
      data_out <= (others => RESET_VALUE);
    else
      delay_line := delay_line(delay_line'high-1 downto 0) & data_in;
      data_out <= delay_line(delay_line'high);
    end if;
  end if;

end process;

end architecture;

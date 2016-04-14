-- Fully pipelined complex AXI stream multiplier with generic widths
--
-- Original author Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ComplexMultiplier is
  generic (
  A_WIDTH : natural := 16;
  B_WIDTH : natural := 16;
  PROD_WIDTH : natural := 16;
  -- normally complex multiplication grows by one bit e.g. -1-1im * -1-1im  = 0 + 2im
  -- divide output by BIT_SHIFT if overflow not a concern e.g. multplying by e^i\theta
  BIT_SHIFT : natural := 0
  );
  port (
  clk : in std_logic;
  rst : in std_logic;

  a_data_re : in std_logic_vector(A_WIDTH-1 downto 0);
  a_data_im : in std_logic_vector(A_WIDTH-1 downto 0);
  a_vld : in std_logic;
  a_last : in std_logic;

  b_data_re : in std_logic_vector(B_WIDTH-1 downto 0);
  b_data_im : in std_logic_vector(B_WIDTH-1 downto 0);
  b_vld : in std_logic;
  b_last : in std_logic;

  prod_data_re : out std_logic_vector(PROD_WIDTH-1 downto 0);
  prod_data_im : out std_logic_vector(PROD_WIDTH-1 downto 0);
  prod_vld : out std_logic;
  prod_last : out std_logic
  );
end entity;

architecture arch of ComplexMultiplier is

signal a_reg_re, a_reg_im : signed(A_WIDTH-1 downto 0);
signal b_reg_re, b_reg_im : signed(B_WIDTH-1 downto 0);

constant PROD_WIDTH_INT : natural := A_WIDTH + B_WIDTH;
signal prod1, prod2, prod3, prod4 : signed(PROD_WIDTH_INT-1 downto 0);
signal sum_re, sum_im : signed(PROD_WIDTH_INT-1 downto 0);

--How to slice the output sum
subtype OUTPUT_SLICE  is natural range (PROD_WIDTH_INT - 1 - BIT_SHIFT) downto (PROD_WIDTH_INT - BIT_SHIFT - PROD_WIDTH);

begin

  main : process( clk )
  begin
  	if rising_edge(clk) then
  		if rst = '1' then
        a_reg_re <= (others => '0');
        a_reg_im <= (others => '0');
        b_reg_re <= (others => '0');
        b_reg_im <= (others => '0');

        prod1 <= (others => '0');
        prod2 <= (others => '0');
        prod3 <= (others => '0');
        prod4 <= (others => '0');

        sum_re <= (others => '0');
        sum_im <= (others => '0');
        prod_data_re <= (others => '0');
        prod_data_im <= (others => '0');

  		else
        --Register inputs
        a_reg_re <= signed(a_data_re);
        a_reg_im <= signed(a_data_im);
        b_reg_re <= signed(b_data_re);
        b_reg_im <= signed(b_data_im);

        --Pipeline intermediate products
        prod1 <= a_reg_re * b_reg_re;
        prod2 <= a_reg_re * b_reg_im;
        prod3 <= a_reg_im * b_reg_re;
        prod4 <= a_reg_im * b_reg_im;

        --don't have to worry about overflow because signed multiplication already has extra bit
        sum_re <= prod1 - prod4;
        sum_im <= prod2 + prod3;

        --Slice output to truncate
        prod_data_re <= std_logic_vector( sum_re(OUTPUT_SLICE) );
        prod_data_im <= std_logic_vector( sum_im(OUTPUT_SLICE) );

  		end if;
  	end if;
  end process; -- main

  --Delay the valid and last for the pipelining through the multiplier
  --Currently this is 4 clocks: input register; products; additions; output register

  --Both inputs have to be valid
  delayLine_vld : entity work.DelayLine
  generic map(DELAY_TAPS => 4)
  port map(clk => clk, rst => rst, data_in(0) => (a_vld and b_vld), data_out(0) => prod_vld);

  --Either last -- unaligned lasts is not defined behaviour
  delayLine_last : entity work.DelayLine
  generic map(DELAY_TAPS => 4)
  port map(clk => clk, rst => rst, data_in(0) => (a_last or b_last), data_out(0) => prod_last);

end architecture;

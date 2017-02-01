----
-- Original author: Blake Johnson
-- Copyright 2017, Raytheon BBN Technologies
--
-- A pseudorandom number generator of the PCG family (M.E. O'Neill 2017).
-- The specific version we choose is the "PGC-XSH-RR" generator which combines
-- a simple LCG with a permutation function composed of an xorshift and a bit
-- rotation. The implementation is pipelined to allow it to run at high clock
-- speeds.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity PCG_XSH_RR is
    port (
        rst   : in std_logic;
        clk   : in std_logic;
        seed  : in std_logic_vector(63 downto 0);
        rand  : out std_logic_vector(31 downto 0);
        valid : out std_logic
    );
end entity;

architecture arch of PCG_XSH_RR is

signal state : unsigned(63 downto 0);

type permutation_state_t is (XORSHIFT_STATE, ROTATION_STATE);
signal perm_state : permutation_state_t := XORSHIFT_STATE;

begin

LCG : process(clk)
-- multiplicative constant comes from PCG basic implementation
-- https://github.com/imneme/pcg-c-basic
constant LCG_MULT : unsigned(63 downto 0) := 64d"6364136223846793005";
constant LCG_ADD  : unsigned(63 downto 0) := 64d"2531011"; -- can be any odd number
variable tmp      : unsigned(127 downto 0);

begin
    if rising_edge(clk) then
        if rst = '1' then
            state <= unsigned(seed);
        else
            if perm_state = ROTATION_STATE then
                tmp := LCG_MULT * state;
                state <= tmp(63 downto 0) + LCG_ADD;
            end if;
        end if;
    end if;
end process;

permutation_function : process(clk)
variable xorshift : unsigned(31 downto 0);
variable rotation : natural range 0 to 31 := 0;
begin
    if rising_edge(clk) then
        if rst = '1' then
            rand <= (others => '0');
            valid <= '0';
            perm_state <= XORSHIFT_STATE;
            rotation := 0;
        else
            case (perm_state) is
            when XORSHIFT_STATE =>
                -- compute 32-bit xorshift
                -- xorshift := (state ^ (state >> 18)) >> 27
                xorshift := state(59 downto 28) xor state(49 downto 18);

                rotation := to_integer(state(63 downto 59));
                valid <= '0';

                perm_state <= ROTATION_STATE;

            when ROTATION_STATE =>
                rand <= std_logic_vector(xorshift ror rotation);
                valid <= '1';

                perm_state <= XORSHIFT_STATE;
            end case;
        end if;
    end if;
end process;

end architecture;

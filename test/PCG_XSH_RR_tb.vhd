-- test bench for the PCG pseudorandom number generator
--
-- Original author: Blake Johnson
-- Copyright 2017 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PCG_XSH_RR_tb is
end;

architecture bench of PCG_XSH_RR_tb is

    signal clk               : std_logic := '0';
    signal rst               : std_logic := '0';

    constant clock_period    : time := 4.0 ns;
    signal stop_the_clock    : boolean := false;
    signal checking_finished : boolean := false;
    constant LATENCY : natural := 3;

    signal seed     : std_logic_vector(63 downto 0) := std_logic_vector(to_unsigned(1234, 64));
    signal rand_out : std_logic_vector(31 downto 0);
    signal valid    : std_logic;

    type rand_array is array(0 to 7) of std_logic_vector(31 downto 0);
    signal rand_outs : rand_array := (others => (others => '0'));
    -- expected outs computed using PCG.jl:
    -- julia> include("PCG.jl")
    -- julia> using PCG
    -- julia> g = PCG(1234)
    -- julia> [rand(g) for _ in 1:8]
    signal expected_outs : rand_array := (
        0 => x"00000000",
        1 => x"cb267ac2",
        2 => x"035401a4",
        3 => x"3db8c0ea",
        4 => x"45b49a87",
        5 => x"42f4a7aa",
        6 => x"d6016e1c",
        7 => x"3922cc67"
    );


    type TestBenchState_t is (RESET, TEST_RAND, FINISHED);
    signal test_bench_state : TestBenchState_t;

begin

    uut: entity work.PCG_XSH_RR
    port map (
        clk => clk,
        rst => rst,
        seed => seed,
        rand => rand_out,
        valid => valid
    );

    clk <= not clk after clock_period / 2 when not stop_the_clock;

    stimulus : process
    begin

        ---------------------------
        test_bench_state <= RESET;
        rst <= '1';
        wait for 20 ns;
        wait until rising_edge(clk);
        rst <= '0';

        test_bench_state <= TEST_RAND;

        for ct in rand_outs'range loop
            wait until rising_edge(valid);
            rand_outs(ct) <= rand_out;
        end loop;

        test_bench_state <= FINISHED;
        wait for 100 ns;
        stop_the_clock <= true;
        wait;

    end process;

    checking : process
    begin

        wait until rising_edge(clk) and test_bench_state = FINISHED;

        for ct in rand_outs'range loop
            -- compare against a known result
            assert rand_outs(ct) = expected_outs(ct) report "PCG output error: expected " &
                integer'image( to_integer( unsigned(expected_outs(ct) ) )) & " but got " &
                integer'image( to_integer( unsigned(rand_outs(ct) ) ));
        end loop;

        report "FINISHED PCG output checking";
        checking_finished <= true;

    end process;

end;

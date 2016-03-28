-- Testbench for the Polyphase_SSB module
--
-- Original authors Diego Riste and Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity PolyphaseSSB_tb is
end;

architecture bench of PolyphaseSSB_tb is

signal clk, clk_oserdes: std_logic := '0';
signal reset: std_logic := '0';

constant CLK_PERIOD         : time := 4ns;
constant CLK_OSERDES_PERIOD : time := 2ns;
constant IN_DATA_WIDTH      : natural := 14;
constant OUT_DATA_WIDTH     : natural := 14;
constant OUT_DATA_SCALE     : integer := 2**(OUT_DATA_WIDTH-1)-1;

signal wfm_in_re   : std_logic_vector(4*IN_DATA_WIDTH-1 downto 0) := (others => '0');
signal wfm_in_im   : std_logic_vector(4*IN_DATA_WIDTH-1 downto 0) := (others => '0');
signal phinc       : std_logic_vector(23 downto 0) := (others => '0');
signal phoff       : std_logic_vector(23 downto 0) := (others => '0');
signal wfm_out_re  : std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
signal wfm_out_im  : std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
signal wfm_out_vld : std_logic := '0';

signal wfm_oserdes_re, wfm_oserdes_im : std_logic_vector(OUT_DATA_WIDTH-1 downto 0);

--define different stages for testbench, corresponding to different SSB parameters
type TESTBENCH_STATE_t	is (RESETTING, BASEBAND_RAMP_RE, BASEBAND_PH_SHIFT, SSB_ON, SSB_PH_SHIFT, MAX_RANGE, DONE);
signal testbench_state : TESTBENCH_STATE_t;

signal stop_the_clocks : boolean := false;
signal checking_finished : boolean := false;

begin

uut: entity work.PolyphaseSSB
	generic map (
		IN_DATA_WIDTH  => IN_DATA_WIDTH,
		OUT_DATA_WIDTH => OUT_DATA_WIDTH
	)
	port map (
		clk           => clk,
		rst           => reset,
		phase_increment => phinc,
		phase_offset    => phoff,
		waveform_in_re  => wfm_in_re,
		waveform_in_im  => wfm_in_im,
		waveform_out_re => wfm_out_re,
		waveform_out_im => wfm_out_im,
		out_vld         => wfm_out_vld
	 );

oserdes_re: entity work.FakeOSERDES
	generic map (
		SAMPLE_WIDTH => OUT_DATA_WIDTH,
		CLK_PERIOD => CLK_OSERDES_PERIOD
	)
	port map (
		clk_in   => clk_oserdes,
		reset    => reset,
		data_in  => wfm_out_re,
		data_out => wfm_oserdes_re
	);

oserdes_im: entity work.FakeOSERDES
generic map (
	SAMPLE_WIDTH => OUT_DATA_WIDTH,
	CLK_PERIOD => CLK_OSERDES_PERIOD
)
port map (
	clk_in   => clk_oserdes,
	reset    => reset,
	data_in  => wfm_out_im,
	data_out => wfm_oserdes_im
);


clk <= not clk after CLK_PERIOD/2 when not stop_the_clocks;
clk_oserdes <= not clk_oserdes after CLK_OSERDES_PERIOD/2 when not stop_the_clocks;

stimulus: process
	constant MAX_INPUT : std_logic_vector(4*IN_DATA_WIDTH-1 downto 0) :=
	std_logic_vector(to_signed(2**(IN_DATA_WIDTH-1)-1, IN_DATA_WIDTH))
	& std_logic_vector(to_signed(2**(IN_DATA_WIDTH-1)-1, IN_DATA_WIDTH))
	& std_logic_vector(to_signed(2**(IN_DATA_WIDTH-1)-1, IN_DATA_WIDTH))
	& std_logic_vector(to_signed(2**(IN_DATA_WIDTH-1)-1, IN_DATA_WIDTH));
begin

	--Resetting
	testbench_state <= RESETTING;
	reset <= '1';
	wait for 100ns;
	reset <= '0';
	wait for 20ns;
	wait until rising_edge(clk);

	--clk in baseband ramp on real axis
	testbench_state <= BASEBAND_RAMP_RE;
	for i in -2048 to 2047 loop
		--ramp from min to max
		wfm_in_re <= std_logic_vector(to_signed(4*i+3, IN_DATA_WIDTH))
									& std_logic_vector(to_signed(4*i+2, IN_DATA_WIDTH))
									& std_logic_vector(to_signed(4*i+1, IN_DATA_WIDTH))
									& std_logic_vector(to_signed(4*i, IN_DATA_WIDTH));
		wait until rising_edge(clk);
	end loop ;

	testbench_state <= BASEBAND_PH_SHIFT;
	--set I quadrature to max
	wfm_in_re <= MAX_INPUT;
	--shift phase by pi/2 (2^22, 1/4 circle)
	phoff <= std_logic_vector(to_unsigned(2**22, 24));
	wait for 1 us;

	testbench_state <= SSB_ON;
	phoff <= (others => '0');
	--turn on SSB mod.,  (2^24, 1/100 clk)
	phinc <= std_logic_vector(to_unsigned((2**24)/64, 24));
	wait for 10 us;

	testbench_state <= SSB_PH_SHIFT;
	--shift phase by pi/2
	phoff <= std_logic_vector(to_unsigned(2**22, 24));
	wait for 10 us;

	testbench_state <= MAX_RANGE;
	--set I and Q quadratures to max
	wfm_in_re <= MAX_INPUT;
	wfm_in_im <= MAX_INPUT;

	wait for 10 us;

	testbench_state <= DONE;
	wait for 100ns;
	assert checking_finished report "Checking process failed to finish!";
	stop_the_clocks <= true;
	wait;
end process;


check : process
	variable ind : integer := 0;
	variable wfm_check_re : signed(OUT_DATA_WIDTH-1 downto 0);
	variable wfm_check_im : signed(OUT_DATA_WIDTH-1 downto 0);
	variable slice_re : signed(OUT_DATA_WIDTH-1 downto 0);
	variable slice_im : signed(OUT_DATA_WIDTH-1 downto 0);
begin
	--the while loop repeat until the condition is met for the first time (to sync. with wfm_out_xx).
	wait until testbench_state = BASEBAND_RAMP_RE;
	wait until rising_edge(clk) and wfm_out_re /= std_logic_vector(to_signed(0, wfm_out_re'length));
	for ct in -2048 to 2047 loop
		--ramp amplitude
		for ct2 in 0 to 3 loop
			wfm_check_re := to_signed(2**(OUT_DATA_WIDTH-IN_DATA_WIDTH)*(4*ct + ct2), OUT_DATA_WIDTH);
			--Arbitrarly allow difference of 2 due to fixed point errors
			slice_re := signed(wfm_out_re((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			slice_im := signed(wfm_out_im((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			assert abs(wfm_check_re - slice_re) <= 2 report "real output wrong in BASEBAND_RAMP_RE! expected " & integer'image(to_integer(wfm_check_re)) & " but got " & integer'image(to_integer(slice_re)) ;
			assert abs(slice_im) <= 2 report "imag output wrong in BASEBAND_RAMP_RE! expected " & integer'image(to_integer(wfm_check_im)) & " but got " & integer'image(to_integer(slice_im)) ;
		end loop;
		wait until rising_edge(clk);
	end loop ;
	report "Finished checking BASEBAND_RAMP_RE";

	wait until rising_edge(clk) and testbench_state = BASEBAND_PH_SHIFT;
	--wait until DDS is valid (3 cycles) and multiplier pipeline delay (4 cycles)
	for ct in 0 to 7 loop
		wait until rising_edge(clk);
	end loop;
	--shift phase by pi/2
	wfm_check_im := to_signed(OUT_DATA_SCALE, OUT_DATA_WIDTH);
	wfm_check_re := (others => '0');
	assert abs(wfm_check_re - signed(wfm_oserdes_re)) <= 2 report "real output wrong in BASEBAND_PH_SHIFT!";
	assert abs(wfm_check_im - signed(wfm_oserdes_im)) <= 2 report "imag output wrong in BASEBAND_PH_SHIFT!";
	report "Finished checking BASEBAND_PH_SHIFT";

	wait until rising_edge(clk) and testbench_state = SSB_ON;
	--wait until DDS is valid (3 cycles) and multiplier pipeline delay (4 cycles)
	for ct in 0 to 7 loop
		wait until rising_edge(clk);
	end loop ;

	ind := 7;
	while testbench_state /= SSB_PH_SHIFT loop
		for ct2 in 0 to 3 loop
			ind := ind+1;
			wfm_check_re := to_signed(integer(cos(2.0*MATH_PI*0.25*(1.0/64)*real(ind))*real(OUT_DATA_SCALE)), OUT_DATA_WIDTH);
			wfm_check_im := to_signed(integer(sin(2.0*MATH_PI*0.25*(1.0/64)*real(ind))*real(OUT_DATA_SCALE)), OUT_DATA_WIDTH);
			--Arbitrarly allow differences of 8 due to fixed point errors
			slice_re := signed(wfm_out_re((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			slice_im := signed(wfm_out_im((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			assert abs(wfm_check_re - slice_re) <= 8 report "real output wrong in SSB_ON! expected " & integer'image(to_integer(wfm_check_re)) & " but got " & integer'image(to_integer(slice_re)) ;
			assert abs(wfm_check_im - slice_im) <= 8 report "imag output wrong in SSB_ON! expected " & integer'image(to_integer(wfm_check_im)) & " but got " & integer'image(to_integer(slice_im)) ;
		end loop;
		wait until rising_edge(clk);
	end loop;
	report "Finished checking SSB_ON";

	--wait until DDS is valid (3 cycles) and multiplier pipeline delay (4 cycles)
	for ct in 0 to 7 loop
		wait until rising_edge(clk);
		ind := ind + 4;
	end loop;

	while testbench_state /= MAX_RANGE loop
		for ct2 in 0 to 3 loop
			ind := ind+1;
			--cos(2pi * freq * time); freq and time are in timestep units; freq is 1/4 because of 4 wide samples
			wfm_check_re := to_signed(integer(cos(2.0*MATH_PI*0.25*(1.0/64)*real(ind) + MATH_PI/2.0)*real(OUT_DATA_SCALE)), OUT_DATA_WIDTH);
			wfm_check_im := to_signed(integer(sin(2.0*MATH_PI*0.25*(1.0/64)*real(ind) + MATH_PI/2.0)*real(OUT_DATA_SCALE)), OUT_DATA_WIDTH);
			--Arbitrarly allow difference of 8 due to fixed point errors
			slice_re := signed(wfm_out_re((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			slice_im := signed(wfm_out_im((ct2+1)*OUT_DATA_WIDTH-1 downto ct2*OUT_DATA_WIDTH));
			assert abs(wfm_check_re - slice_re) <= 8 report "real output wrong in SSB_PH_SHIFT! expected " & integer'image(to_integer(wfm_check_re)) & " but got " & integer'image(to_integer(slice_re)) ;
			assert abs(wfm_check_im - slice_im) <= 8 report "imag output wrong in SSB_PH_SHIFT! expected " & integer'image(to_integer(wfm_check_im)) & " but got " & integer'image(to_integer(slice_im)) ;
		end loop;
		wait until rising_edge(clk);
	end loop;
	report "Finished checking SSB_PH_SHIFT";

	checking_finished <= true;
	wait;
end process ;

end;

-- Modulates a complex 4 sample wide waveform stream for SSB modulation
--
-- Uses 16 DSP slices: 4 * (2 per ComplexMultiplier and 2 per DDS)
--
-- Original authors Diego Riste and Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.std_logic_misc.and_reduce; --just use and in vhdl-2008

entity PolyphaseSSB is
	generic (
		IN_DATA_WIDTH : natural := 16;
		OUT_DATA_WIDTH : natural := 16;
		ACCUMULATOR_WIDTH : natural := 24
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		phase_increment : in std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0); --signed N-bit integer (portion of circle)
		phase_offset    : in std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0); --signed N-bit integer (portion of circle)

		waveform_in_re : in std_logic_vector(4*IN_DATA_WIDTH-1 downto 0);
		waveform_in_im : in std_logic_vector(4*IN_DATA_WIDTH-1 downto 0);

		waveform_out_re : out std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
		waveform_out_im : out std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
		out_vld         : out std_logic
	) ;
end entity ; -- PolyphaseSSB

architecture arch of PolyphaseSSB is

signal dds_vld : std_logic_vector(3 downto 0) := (others => '0');
signal prod_vld : std_logic_vector(3 downto 0) := (others => '0');

type SINCOS_ARRAY_t is array(0 to 3) of std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
type PHASE_ARRAY_t is array(0 to 3) of signed(ACCUMULATOR_WIDTH-1 downto 0);

signal cos_array, sin_array : SINCOS_ARRAY_t := (others => (others => '0'));
signal phase_offsets : PHASE_ARRAY_t := (others => (others => '0'));

signal base_phase : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
signal phases : PHASE_ARRAY_t := (others => (others => '0'));

begin

	--Base phase accumulator at 1/4 rate
	base_phase_accum : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				base_phase <= (others => '0');
			else
				base_phase <= base_phase + signed(phase_increment);
			end if;
		end if;
	end process;

	--skew the offset for each of the four samples to interpolate
	--skew by 0,1/4,1/2,3/4 of phase_increment
	phase_offset_skew : process(clk)
	begin
		if rising_edge(clk) then
			phase_offsets(0) <= signed(phase_offset);
			phase_offsets(1) <= signed(phase_offset) + shift_right(signed(phase_increment),2);
			phase_offsets(2) <= signed(phase_offset) + shift_right(signed(phase_increment),1);
			phase_offsets(3) <= signed(phase_offset) + shift_right(signed(phase_increment),1) + shift_right(signed(phase_increment),2);
		end if;
	end process;

	--output all 4 phases
	phase_outputs : process(clk)
	begin
		if rising_edge(clk) then
			for ct in 0 to 3 loop
				phases(ct) <= base_phase + phase_offsets(ct);
			end loop;
		end if;
	end process;

	--generate the sin/cos LUTs
	sincos_lut_gen : for ct in 0 to 3 generate
		sincos_lut_inst : entity work.SinCosLUT
			generic map (
				PHASE_WIDTH => OUT_DATA_WIDTH,
				OUTPUT_WIDTH => OUT_DATA_WIDTH
			)
			port map (
				clk => clk,
				rst => rst,
				phase_tdata  => std_logic_vector(phases(ct)(phases(ct)'high downto phases(ct)'high-OUT_DATA_WIDTH+1)),
				phase_tvalid => '1',

				sin_tdata => sin_array(ct),
				cos_tdata => cos_array(ct),
				sincos_tvalid => dds_vld(ct)
			);
	end generate;

	ComplexMultipliergen : for ct in 0 to 3 generate
		myComplexMultiplier : entity work.ComplexMultiplier
			generic map (
				A_WIDTH => IN_DATA_WIDTH,
				B_WIDTH => OUT_DATA_WIDTH,
				PROD_WIDTH => OUT_DATA_WIDTH,
				BIT_SHIFT => 2
			)
			port map (
				clk => clk,
				rst => rst,
				a_data_re => waveform_in_re((ct+1)*IN_DATA_WIDTH-1 downto ct*IN_DATA_WIDTH),
				a_data_im => waveform_in_im((ct+1)*IN_DATA_WIDTH-1 downto ct*IN_DATA_WIDTH),
				a_vld => '1',
				a_last => '0',

				b_data_re => cos_array(ct),
				b_data_im => sin_array(ct),
				b_vld => dds_vld(ct),
				b_last => '0',

				prod_data_re => waveform_out_re((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_data_im => waveform_out_im((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_vld => prod_vld(ct)
				);
	end generate ; -- ComplexMultipliergen

	out_vld <= and_reduce(prod_vld); -- just and in VHDL-2008

end architecture ; -- arch

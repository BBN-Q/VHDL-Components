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
		OUT_DATA_WIDTH : natural := 16
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		phase_increment : in std_logic_vector(23 downto 0); --unsigned 24-bit integer (portion of circle)
		phase_offset    : in std_logic_vector(23 downto 0); --unsigned 24-bit integer (portion of circle)

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

type DDS_sincos_t is array(0 to 3) of std_logic_vector(15 downto 0);
type DDS_phoff_t is array(0 to 3) of std_logic_vector(23 downto 0);

signal DDS_cos_array, DDS_sin_array : DDS_sincos_t := (others => (others => '0'));
signal DDS_phoff_array : DDS_phoff_t := (others => (others => '0'));

begin

	ComplexMultipliergen : for ct in 0 to 3 generate
		myComplexMultiplier : entity work.ComplexMultiplier
			generic map (
				A_WIDTH => IN_DATA_WIDTH,
				B_WIDTH => 16,
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

				b_data_re => DDS_cos_array(ct),
				b_data_im => DDS_sin_array(ct),
				b_vld => dds_vld(ct),
				b_last => '0',

				prod_data_re => waveform_out_re((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_data_im => waveform_out_im((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_vld => prod_vld(ct)
				);
	end generate ; -- ComplexMultipliergen

	out_vld <= and_reduce(prod_vld); -- just and in VHDL-2008

	--an instance of DDS for each of the 4 samples
	phase_offset_register : process(clk)
	begin
		if rising_edge(clk) then
			DDS_phoff_array(0) <= phase_offset;
			DDS_phoff_array(1) <= std_logic_vector(signed(phase_offset) + shift_right(signed(phase_increment),2));
			DDS_phoff_array(2) <= std_logic_vector(signed(phase_offset) + shift_right(signed(phase_increment),1));
			DDS_phoff_array(3) <= std_logic_vector(signed(phase_offset) + shift_right(signed(phase_increment),1) + shift_right(signed(phase_increment),2));
		end if;
	end process;

	DDSgen : for ct in 0 to 3 generate
		myDDS : entity work.DDS_PolyPhaseSSB
		port map (
			aclk => clk,
			aresetn => "not"(rst),
			s_axis_phase_tvalid => '1',
			s_axis_phase_tdata => DDS_phoff_array(ct) & phase_increment,
			m_axis_data_tvalid => dds_vld(ct),
			m_axis_data_tdata(31 downto 16) => DDS_sin_array(ct),
			m_axis_data_tdata(15 downto 0) => DDS_cos_array(ct)
		);
	end generate ; -- DDSgen

end architecture ; -- arch

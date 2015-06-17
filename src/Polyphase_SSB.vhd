-- Modulates a complex 4 sample wide waveform stream for SSB modulation
--
-- Uses 16 DSP slices: 4 * (2 per ComplexMultiplier and 2 per DDS)
--
-- Original authors Diego Riste and Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;

use IEEE.std_logic_misc.and_reduce; --just use and in VHDL-2008

entity Polyphase_SSB is
	generic (
		IN_DATA_WIDTH : natural := 16;
		OUT_DATA_WIDTH : natural := 16
	);
	port (
		clock : in std_logic;
		reset : in std_logic;

		phinc : in std_logic_vector(23 downto 0); --unsigned 24-bit integer (portion of circle)
  	phoff : in std_logic_vector(23 downto 0); --unsigned 24-bit integer (portion of circle)

		waveform_in_re : in std_logic_vector(4*IN_DATA_WIDTH-1 downto 0);
		waveform_in_im : in std_logic_vector(4*IN_DATA_WIDTH-1 downto 0);

  	waveform_out_re : out std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
		waveform_out_im : out std_logic_vector(4*OUT_DATA_WIDTH-1 downto 0);
		out_vld         : out std_logic
	) ;
end entity ; -- Polyphase_SSB

architecture arch of Polyphase_SSB is

signal DDS_vld : std_logic_vector(3 downto 0) := (others => '0');
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
				clk => clock,
				rst => reset,
				a_data_re => waveform_in_re((ct+1)*IN_DATA_WIDTH-1 downto ct*IN_DATA_WIDTH),
				a_data_im => waveform_in_im((ct+1)*IN_DATA_WIDTH-1 downto ct*IN_DATA_WIDTH),
				a_vld => '1',
				a_last => '0',

				b_data_re => DDS_cos_array(ct),
				b_data_im => DDS_sin_array(ct),
				b_vld => DDS_vld(ct),
				b_last => '0',

				prod_data_re => waveform_out_re((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_data_im => waveform_out_im((ct+1)*OUT_DATA_WIDTH-1 downto ct*OUT_DATA_WIDTH),
				prod_vld => prod_vld(ct)
				);
	end generate ; -- ComplexMultipliergen

	out_vld <= and_reduce(prod_vld); -- just and in VHDL-2008

	--an instance of DDS for each of the 4 samples
	DDS_phoff_array(0) <=  phoff;
	DDS_phoff_array(1) <=  std_logic_vector(signed(phoff) + shift_right(signed(phinc),2));
	DDS_phoff_array(2) <=  std_logic_vector(signed(phoff) + shift_right(signed(phinc),1));
	DDS_phoff_array(3) <=  std_logic_vector(signed(phoff) + shift_right(signed(phinc),1) + shift_right(signed(phinc),2));

	DDSgen : for ct in 0 to 3 generate
		myDDS : entity work.DDS
		port map (
			aclk => clock,
			aresetn => "not"(reset),
			s_axis_phase_tvalid => '1',
			s_axis_phase_tdata => DDS_phoff_array(ct),
			s_axis_config_tvalid => '1',
			s_axis_config_tdata => phinc,
			m_axis_data_tvalid => DDS_vld(ct),
			m_axis_data_tdata(31 downto 16) => DDS_sin_array(ct),
			m_axis_data_tdata(15 downto 0) => DDS_cos_array(ct)
		);
	end generate ; -- DDSgen

end architecture ; -- arch

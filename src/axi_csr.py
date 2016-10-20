"""
Python script to create an AXI memory mapped CSR.
"""

from math import ceil, log2
from jinja2 import Template

class Register(object):
	"""A single register in a CSR"""
	def __init__(self, addr, label, mode, initial_value=0):
		super(Register, self).__init__()
		self.addr = addr
		self.label = label
		self.mode = mode
		self.initial_value = initial_value

t = Template("""-- AXI memory mapped CSR registers
--
-- Original authors: Colm Ryan, Brian Donovan
-- Copyright 2015-2016, Raytheon BBN Technologies


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {{MODULE_NAME}} is
port (
	--CSR control ports
	{%- for reg in registers|selectattr("mode", "equalto", "write") %}
	{{reg.label.ljust(JUSTIFICATION_WIDTH)}} : out std_logic_vector(31 downto 0);
	{%- endfor %}

	-- CSR status ports
	{%- for reg in registers|selectattr("mode", "equalto", "read") %}
	{{reg.label.ljust(JUSTIFICATION_WIDTH)}} : in std_logic_vector(31 downto 0);
	{%- endfor %}

	-- slave AXI bus
	s_axi_aclk    : in std_logic;
	s_axi_aresetn : in std_logic;
	s_axi_awaddr  : in std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
	s_axi_awprot  : in std_logic_vector(2 downto 0);
	s_axi_awvalid : in std_logic;
	s_axi_awready : out std_logic;
	s_axi_wdata   : in std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
	s_axi_wstrb   : in std_logic_vector({{REGISTER_BYTE_WIDTH-1}} downto 0);
	s_axi_wvalid  : in std_logic;
	s_axi_wready  : out std_logic;
	s_axi_bresp   : out std_logic_vector(1 downto 0);
	s_axi_bvalid  : out std_logic;
	s_axi_bready  : in std_logic;
	s_axi_araddr  : in std_logic_vector({{AXI_ADDR_WIDTH-1}} downto 0);
	s_axi_arprot  : in std_logic_vector(2 downto 0);
	s_axi_arvalid : in std_logic;
	s_axi_arready : out std_logic;
	s_axi_rdata   : out std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
	s_axi_rresp   : out std_logic_vector(1 downto 0);
	s_axi_rvalid  : out std_logic;
	s_axi_rready  : in std_logic
	);
end entity;

architecture arch of {{MODULE_NAME}} is

	-- register size (AXI address is byte wide)
	constant NUM_REGS : natural := {{NUM_REGS}};
	-- array of registers
	type REG_ARRAY_t is array(natural range <>) of std_logic_vector({{REGISTER_WIDTH-1}} downto 0) ;
	signal regs : REG_ARRAY_t(0 to NUM_REGS-1) := (others => (others => '0'));
	signal write_reg_addr : integer range 0 to NUM_REGS-1;
	signal read_reg_addr  : integer range 0 to NUM_REGS-1;

	-- internal AXI signals
	signal axi_awready : std_logic;
	signal axi_wready  : std_logic;
	signal axi_wdata   : std_logic_vector({{REGISTER_WIDTH-1}} downto 0);
	signal axi_wstrb   : std_logic_vector({{REGISTER_BYTE_WIDTH-1}} downto 0);
	signal axi_bvalid  : std_logic;
	signal axi_arready : std_logic;
	signal axi_rvalid  : std_logic;

begin

	-- wire control/status ports to internal registers
	{%- for reg in registers|selectattr("mode", "equalto", "write") %}
	{{reg.label.ljust(JUSTIFICATION_WIDTH)}} <= regs({{reg.addr}});
	{%- endfor %}
	read_regs_register_pro: process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			{%- for reg in registers|selectattr("mode", "equalto", "read") %}
			regs({{reg.addr}}) <= {{reg.label}};
			{%- endfor %}
		end if;
	end process;

	-- connect internal AXI signals
	s_axi_awready <= axi_awready;
	s_axi_wready  <= axi_wready;
	s_axi_bvalid  <= axi_bvalid;
	s_axi_arready <= axi_arready;
	s_axi_rvalid  <= axi_rvalid;


	-- simplistic response to write requests that only handles one write at a time
	-- 1. hold awready and wready low
	-- 2. wait until both awvalid and wvalid are asserted
	-- 3. assert awready and wready high; latch write address and data
	-- 4. update control register
	-- 5. always respond with OK
	s_axi_bresp <= "00";

	write_ready_pro : process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			if s_axi_aresetn = '0' then
				axi_awready <= '0';
				axi_wready <= '0';
				axi_bvalid <= '0';
			else
				if (axi_awready = '0' and axi_wready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1') then
					axi_awready <= '1';
					axi_wready  <= '1';
				else
					axi_awready <= '0';
					axi_wready  <= '0';
				end if;

				-- once writing set response valid high until accepted
				if axi_wready = '1' then
					axi_bvalid <= '1';
				elsif axi_bvalid = '1' and s_axi_bready = '1' then
					axi_bvalid <= '0';
				end if;
			end if;
		end if;
	end process;

	-- update control / internal registers
	update_write_regs_pro : process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then
			-- decode register address
			write_reg_addr <= to_integer(unsigned(s_axi_awaddr(s_axi_awaddr'high downto {{LOG2_REGISTER_BYTE_WIDTH}})));
			-- register data and byte enables
			axi_wdata <= s_axi_wdata;
			axi_wstrb <= s_axi_wstrb;

			if s_axi_aresetn = '0' then
				{%- for reg in registers|rejectattr("mode", "equalto", "read") %}
				regs({{reg.addr}}) <= x"{{"{:08x}".format(reg.initial_value)}}"; -- {{reg.label}}
				{%- endfor %}

			else
				for ct in 0 to {{REGISTER_BYTE_WIDTH-1}} loop
					if axi_wstrb(ct) = '1' and axi_wready = '1' then
						{%- for reg in registers|rejectattr("mode", "equalto", "read") %}
						-- {{reg.label}}
						if write_reg_addr = {{reg.addr}} then
							regs({{reg.addr}})(ct*8+7 downto ct*8) <= axi_wdata(ct*8+7 downto ct*8);
						end if;
						{%- endfor %}
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- read response
	-- respond with data one clock later
	s_axi_rresp <= "00"; -- always OK

	read_response_pro : process (s_axi_aclk)
	begin
		if rising_edge(s_axi_aclk) then

			if s_axi_aresetn = '0' then
				axi_arready <= '0';
				read_reg_addr <= 0;
				s_axi_rdata <= (others => '0');
				axi_rvalid <= '0';
			else
				-- acknowledge and latch address when no outstanding read responses
				if axi_arready = '0' and s_axi_arvalid = '1' then
					axi_arready <= '1';
					-- latch register address
					read_reg_addr <= to_integer(unsigned(s_axi_araddr(s_axi_araddr'high downto {{LOG2_REGISTER_BYTE_WIDTH}})));
				else
					axi_arready <= '0';
				end if;

				-- hold data valid high after latching address and until response
				if axi_arready = '1' then
					axi_rvalid <= '1';
				elsif axi_rvalid = '1' and s_axi_rready = '1' then
					axi_rvalid <= '0';
				end if;

				-- register out data
				s_axi_rdata <= regs(read_reg_addr);

			end if;

		end if;
	end process;

end architecture;
"""
)

def write_axi_csr(filename, registers, module_name="AXI_CSR", register_width=32):

	# check that register width is a power of 2
	assert int(log2(register_width)) == log2(register_width), "register_width must be power of 2"
	register_byte_width = register_width // 8
	log2_register_byte_width = int(log2(register_byte_width))

	# figure out some constants
	ceil_log2_num_regs = ceil( log2(max(reg.addr for reg in registers) ) )
	axi_addr_width = ceil_log2_num_regs + log2_register_byte_width
	num_regs = 2**(ceil_log2_num_regs)

	# maximum register width for some alignment nicieties
	justification_width = max(len(reg.label) for reg in registers if reg.mode == "read" or reg.mode == "write" )

	with open(filename, "w") as FID:
		FID.write(
			t.render(
				MODULE_NAME=module_name,
				registers=registers,
				JUSTIFICATION_WIDTH=justification_width,
				NUM_REGS=num_regs,
				AXI_ADDR_WIDTH=axi_addr_width,
				REGISTER_WIDTH=register_width,
				REGISTER_BYTE_WIDTH=register_byte_width,
				LOG2_REGISTER_BYTE_WIDTH=log2_register_byte_width
				)
			)



if __name__ == '__main__':
	registers = [
					Register(0, "status1", "read"),
					Register(1, "status2", "read"),
					Register(2, "control1", "write", initial_value=0xffffffff),
					Register(3, "control2", "write", initial_value=0x01234567),
					Register(5, "scratch", "internal", initial_value=0x000dba11)
				]

	write_axi_csr("AXI_CSR.vhd", registers, 32)

"""
Python script to create an AXI memory mapped CSR.
"""
from jinja2 import Template

class Register(object):
	"""A single register in a CSR"""
	def __init__(self, label, mode, initial_value=0):
		super(Register, self).__init__()
		self.label = label
		self.mode = mode
		self.initial_value = initial_value

t = Template("""
-- AXI memory mapped CSR registers

-- Original authors: Colm Ryan, Brian Donovan
-- Copyright 2015-2016, Raytheon BBN Technologies


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {{module_name}} is
port (
	-- CSR ports
{%- for reg in register_map.values() %}
	{{reg.label.ljust(just_width)}} : {{'in' if reg.mode=='read' else 'out'}} std_logic_vector(31 downto 0);
{%- endfor %}

	-- slave AXI bus
	s_axi_aclk    : in std_logic;
	s_axi_aresetn : in std_logic;
	s_axi_awaddr  : in std_logic_vector({{S_AXI_ADDR_WIDTH}}-1 downto 0);
	s_axi_awprot  : in std_logic_vector(2 downto 0);
	s_axi_awvalid : in std_logic;
	s_axi_awready : out std_logic;
	s_axi_wdata   : in std_logic_vector({{S_AXI_DATA_WIDTH}}-1 downto 0);
	s_axi_wstrb   : in std_logic_vector(({{S_AXI_DATA_WIDTH}}/8)-1 downto 0);
	s_axi_wvalid  : in std_logic;
	s_axi_wready  : out std_logic;
	s_axi_bresp   : out std_logic_vector(1 downto 0);
	s_axi_bvalid  : out std_logic;
	s_axi_bready  : in std_logic;
	s_axi_araddr  : in std_logic_vector({{S_AXI_ADDR_WIDTH}}-1 downto 0);
	s_axi_arprot  : in std_logic_vector(2 downto 0);
	s_axi_arvalid : in std_logic;
	s_axi_arready : out std_logic;
	s_axi_rdata   : out std_logic_vector({{S_AXI_DATA_WIDTH}}-1 downto 0);
	s_axi_rresp   : out std_logic_vector(1 downto 0);
	s_axi_rvalid  : out std_logic;
	s_axi_rready  : in std_logic
	);
end entity;

architecture arch of {{module_name}} is

	-- register size (AXI address is byte wide)
	constant NUM_REGS : natural := 2**({{S_AXI_ADDR_WIDTH}}-2);
	-- array of registers
	type REG_ARRAY_t is array(natural range <>) of std_logic_vector({{S_AXI_DATA_WIDTH}}-1 downto 0) ;
	signal regs : REG_ARRAY_t(0 to NUM_REGS-1) := (others => (others => '0'));
	signal write_reg_addr : integer range 0 to NUM_REGS-1;
	signal read_reg_addr  : integer range 0 to NUM_REGS-1;

	-- internal AXI signals
	signal axi_awready : std_logic;
	signal axi_wready  : std_logic;
	signal axi_wdata   : std_logic_vector({{S_AXI_DATA_WIDTH}}-1 downto 0);
	signal axi_wstrb   : std_logic_vector(({{S_AXI_DATA_WIDTH}}/8)-1 downto 0);
	signal axi_bvalid  : std_logic;
	signal axi_arready : std_logic;
	signal axi_rvalid  : std_logic;

begin

	-- wire control/status ports to internal registers
	{%- for addr, reg in register_map.items() %}
	{%- if reg.mode == 'write' %}
	{{reg.label}} <= regs({{addr}});
	{%- endif %}
	{%- if reg.mode == 'read' %}
	regs({{addr}}) <= {{reg.label}};
	{%- endif %}
	{%- endfor %}

	-- connect internal AXI signals
	s_axi_awready <= axi_awready;
	s_axi_wready  <= axi_wready;
	s_axi_bvalid  <= axi_bvalid;
	s_axi_arready <= axi_arready;
	s_axi_rvalid  <= axi_rvalid;


	-- simplistic response to write requests that only handles one write at a time
	-- 1. hold awready and wready low
	-- 2. wait until both awvalid and wvalid are asserted high-active
	-- 3. assert awready and wready high; latch write address
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
			write_reg_addr <= to_integer(unsigned(s_axi_awaddr(s_axi_awaddr'high downto 2)));
			-- register data and byte enables
			axi_wdata <= s_axi_wdata;
			axi_wstrb <= s_axi_wstrb;

			-- under reset drive registers to initial values
			if s_axi_aresetn = '0' then
				{%- for addr, reg in register_map.items() %}
				{%- if reg.mode == 'write' or reg.mode == 'internal' %}
				regs({{addr}}) <= x"{{"{:08x}".format(reg.initial_value)}}";
				{%- endif %}
				{%- endfor %}

			-- otherwise update the addressed register
			else
				for ct in 0 to ({{S_AXI_DATA_WIDTH}}/8-1) loop
					if axi_wready = '1' and axi_wstrb(ct) = '1' then
						regs(write_reg_addr)(ct*8+7 downto ct*8) <= axi_wdata(ct*8+7 downto ct*8);
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
				if axi_arready = '0' and axi_rvalid = '1' then
					axi_arready <= '1';
					-- latch register address
					read_reg_addr <= to_integer(unsigned(s_axi_awaddr(s_axi_awaddr'high downto 2)));
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


if __name__ == '__main__':
	register_map = {
					0 : Register("status1", "read"),
					1 : Register("status2", "read"),
					2 : Register("control1", "write", initial_value=0xffffffff),
					3 : Register("control2", "write", initial_value=0x01234567),
				}


	with open("AXI_CSR.vhd", "w") as FID:
		FID.write(
			t.render(
				module_name="AXI_CSR",
				register_map=register_map,
				just_width=10,
				S_AXI_ADDR_WIDTH=8,
				S_AXI_DATA_WIDTH=32
				)
			)

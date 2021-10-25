library ieee;
use ieee.std_logic_1164.all;

entity tbspi is
end tbspi;

architecture rtl of tbspi is

    component spiSlave
    port(
        spiReset    : in  std_logic;
        spiClock    : in  std_logic;

        -- physical pins
        sck         : in  std_logic;
        ncs         : in  std_logic;
        mosi        : in  std_logic;
        miso        : out std_logic;

        -- registers
        REG_control : in  std_logic_vector(15 downto 0);
        REG_status  : out std_logic_vector(15 downto 0);
        REG_receive : out std_logic_vector(15 downto 0);

        -- direction control
        sck_dir     : out std_logic;
        ncs_dir     : out std_logic;
        mosi_dir    : out std_logic;
        miso_dir    : out std_logic;

        --temp Signals
        debugPort   : out std_logic_vector(31 downto 0)
    );
    end component;

    constant spiClockPeriod : time  := 5    ns;
    constant sckClockPeriod : time  := 1000 ns;

    signal   tb_spiReset    : std_logic;  
    signal   tb_spiClock    : std_logic := '0';
    signal   tb_sck         : std_logic := '0';
    signal   tb_ncs         : std_logic;
    signal   tb_mosi        : std_logic;
    signal   tb_miso        : std_logic;
    signal   tb_REG_control : std_logic_vector(15 downto 0);
    signal   tb_REG_status  : std_logic_vector(15 downto 0);
    signal   tb_REG_receive : std_logic_vector(15 downto 0);
    signal   tb_sck_dir     : std_logic;
    signal   tb_ncs_dir     : std_logic;
    signal   tb_mosi_dir    : std_logic;
    signal   tb_miso_dir    : std_logic;
    signal   tb_debugPort   : std_logic_vector(31 downto 0);

begin

    tb_spiClock <= not tb_spiClock after (spiClockPeriod/2.0);
    tb_sck      <= not tb_sck      after (sckClockPeriod/2.0);
    
    spi0: spiSlave port map(
        spiReset    => tb_spiReset   ,  
        spiClock    => tb_spiClock   ,
        sck         => tb_sck        ,
        ncs         => tb_ncs        ,
        mosi        => tb_mosi       ,
        miso        => tb_miso       ,
        REG_control => tb_REG_control,
        REG_status  => tb_REG_status ,
        REG_receive => tb_REG_receive,
        sck_dir     => tb_sck_dir    ,
        ncs_dir     => tb_ncs_dir    ,
        mosi_dir    => tb_mosi_dir   ,
        miso_dir    => tb_miso_dir   ,
        debugPort   => tb_debugPort  
    );

    process begin

    -- We have to manipulate both the fpga clock which runs at 200Mhz and the spi clock which runs at 1Mhz
    --
    -- Signals under 001 Mhz : tb_sck, tb_ncs, tb_mosi, tb_miso
    -- Signals under 200 Mhz : rest of all signals

    -- [1] Initial conditions
        -- [200Mhz]
        tb_spiReset     <= '1';
        tb_REG_control  <= X"0000";
        wait for 5.5 ns; --change data after 5ns
        tb_spiReset  <= '0';

        -- [1Mhz]
        tb_ncs  <= '1';
        tb_mosi <= '0';
        wait for 1100 ns; --change data after 1000ns
        tb_ncs  <= '0';

    
    --[2] Input data for spi at 1 Mhz
        --[1Mhz] data: 0xB1
        tb_mosi <= '1';
        wait for 1000 ns;
    
        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;
    
        --[1Mhz] data : 0xF3
        tb_mosi <= '1';
        wait for 1000 ns;
        
        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '0';
        wait for 1000 ns;

        tb_mosi <= '1';
        wait for 1000 ns;

        tb_mosi <= '1';
        
        
    --[3] Termination conditions for a smooth rollover
        -- [200Mhz]
        wait for 4.5 ns;
        -- [1Mhz]
        wait for 900 ns;

        wait for 500000 ns;
    end process;


end rtl;

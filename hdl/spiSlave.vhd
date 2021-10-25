library ieee;
use ieee.std_logic_1164.all;

entity spiSlave is
    generic(
        GENERIC_SRWIDTH         : integer := 8;
        GENERIC_FIFOWIDTH       : integer := 8;
        GENERIC_FIFODEPTH       : integer := 64;
        GENERIC_FIFOADDRWIDTH   : integer := 6
    );
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
end spiSlave;

architecture rtl of spiSlave is 
    
    signal srReset      : std_logic := '0';
    signal srDataReady  : std_logic;

    signal srData       : std_logic_vector(7 downto 0);
    signal srDataSave   : std_logic_vector(7 downto 0);


    signal fifoClock      : std_logic;
    signal fifoReset      : std_logic;
    signal fifoWriteEn    : std_logic;
    signal fifoReadEn     : std_logic;
    signal fifoDataIn     : std_logic_vector(GENERIC_FIFOWIDTH-1 downto 0);
    signal fifoDataOut    : std_logic_vector(GENERIC_FIFOWIDTH-1 downto 0);
    signal fifoFull       : std_logic;
    signal fifoEmpty      : std_logic;
    signal fifoReadError  : std_logic;
    signal fifoWriteError : std_logic;
    signal fifoDebugPort  : std_logic_vector(31 downto 0);
    
    --[1/2] shift register
    component sr is
        generic(
            SRWIDTH   : integer := GENERIC_SRWIDTH
        );
        port (
            reset     : in  std_logic;
            clock     : in  std_logic;
            enable    : in  std_logic;
            dataIn    : in  std_logic;
            dataReady : out std_logic;
            dataOut   : out std_logic_vector(7 downto 0)
        );
        end component;

    --[2/2] fifo module
    component fifo is
        generic(
            FIFOWIDTH   : integer := GENERIC_FIFOWIDTH;
            FIFODEPTH   : integer := GENERIC_FIFODEPTH;
            ADDRWIDTH   : integer := GENERIC_FIFOADDRWIDTH
        );
        port(
            clock      : in  std_logic;
            reset      : in  std_logic;
            writeEn    : in  std_logic;
            readEn     : in  std_logic;
            dataIn     : in  std_logic_vector(FIFOWIDTH-1 downto 0);
            
            dataOut    : out std_logic_vector(FIFOWIDTH-1 downto 0);
            full       : out std_logic;
            empty      : out std_logic;
    
            writeError : out std_logic;
            readError  : out std_logic;
    
            debugPort  : out std_logic_vector(31 downto 0)
            
        );
    end component;

    begin
        sr0: sr port map(
            reset     => srReset,
            clock     => sck,
            enable    => ncs,
            dataIn    => mosi,
            dataReady => srDataReady,
            dataOut   => srData
        );

        fifo0: fifo port map(
            clock       => fifoClock,
            reset       => fifoReset,
            writeEn     => fifoWriteEn,
            readEn      => fifoReadEn,
            dataIn      => fifoDataIn,
            dataOut     => fifoDataOut,
            full        => fifoFull,
            empty       => fifoEmpty,
            writeError  => fifoWriteError,
            readError   => fifoReadError,
            debugPort   => fifoDebugPort
        );

    -- save data
    process(srDataReady) 
    begin
        if (srDataReady = '1' and srReset = '0') then
            srDataSave  <= srData;
            srReset     <= '1';
        elsif srDataReady = '0' then
            srReset     <= '0';
        end if;
    end process;

    -- pack data

    -- fifo write 

    -- fifo read


    debugPort <= fifoDataOut & X"00" & srDataSave;

end rtl;
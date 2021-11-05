library ieee;
use ieee.std_logic_1164.all;

entity spiSlave is
    generic(
        GENERIC_SRWIDTH         : integer := 8;
        GENERIC_FIFOWIDTH       : integer := 16;
        GENERIC_FIFODEPTH       : integer := 8;
        GENERIC_FIFOADDRWIDTH   : integer := 3
    );
    port(
        -- clock and reset
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

        -- pin direction control
        sck_dir     : out std_logic;
        ncs_dir     : out std_logic;
        mosi_dir    : out std_logic;
        miso_dir    : out std_logic;

        --temp Signals
        debugPort   : out std_logic_vector(15 downto 0);
        debugPortFlags1: out std_logic_vector(3 downto 0);
        debugPortFlags2: out std_logic_vector(3 downto 0);
        debugPortFlags3: out std_logic_vector(3 downto 0);
        debugPortFlags4: out std_logic_vector(7 downto 0)
    );
end spiSlave;

architecture rtl of spiSlave is 

    type savedata_states is (idle, save_srdata, reset_sr, clear_reset);
    type packdata_states is (idle, packLow, packWait, packHigh);
    type fifowrite_states is (idle, write_fifo, check_fullFlag, holdWrite1, holdWrite2);
    type fiforead_states is (idle, read_fifo, fakeRead, futureRead);
    type controlLogic_states is (idle, interruptSAM);

    signal SDSM         : savedata_states;
    signal PDSM         : packdata_states;
    signal FWSM         : fifowrite_states;
    signal FRSM         : fiforead_states;
    signal CLSM         : controlLogic_states;

    ---- Spi signals
    signal spiDataReady     : std_logic := '0';
    signal storeLow         : std_logic := '1';

    ---- Spi register signals ( _fromSAM are control signals and _toSAM are status signals)
    signal readFifo_fromSAM : std_logic;

    signal fifoEmpty_toSAM  : std_logic;


    signal readFifo_fromWSM : std_logic;

    signal readDone_fromRSM : std_logic;
    signal fakedRead_fromRSM: std_logic;

    ---- Shift register signals
    signal srReset      : std_logic := '0';
    signal srData       : std_logic_vector(7 downto 0);
    signal srDataReady  : std_logic;
    signal srDataSave   : std_logic_vector(7 downto 0);
    signal srData16     : std_logic_vector(15 downto 0);

    ---- Fifo signals
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
    signal fifoDataReady  : std_logic;


    --[1/2] shift register module
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

    -- SIGNAL MAPPING AND REGISTER MAPPING
    fifoClock <= spiClock;
    fifoReset <= spiReset;


    ---- CONTROL REGISTER
    readFifo_fromSAM <= REG_control(8);

    ---- STATUS REGISTER
    REG_status(0)  <= fifoEmpty_toSAM;

    ---- RECEIVE REGISTER
    REG_receive <= fifoDataOut;


    -- save data
    SaveDataStateMachine: process(spiClock, srDataReady) 
    begin
        if rising_edge(spiClock) then
        case SDSM is
            when idle => 
                if srDataReady = '1' then
                    SDSM <= save_srdata;
                end if;

            when save_srdata => 
                srDataSave <= srData;
                spiDataReady <= '1';
                SDSM <= reset_sr;

            when reset_sr =>
                srReset <= '1';
                spiDataReady <= '0';
                SDSM <= clear_reset;

            when clear_reset =>
                srReset <= '0';
                SDSM <= idle;
        end case;

        end if;
    end process;

    -- pack data
    PackDataStateMachine: process(spiClock, spiReset) 
    begin

        if spiReset = '1' then
            PDSM <= idle;

        elsif rising_edge(spiClock) then
            case PDSM is
                when idle => 
                    fifoDataReady <= '0';
                    if spiDataReady='1' then
                        PDSM <= packLow;
                    end if;

                when packLow =>
                    srData16(7 downto 0) <= srDataSave;
                    PDSM <= packWait;

                when packWait =>
                    if spiDataReady ='1' then
                        PDSM <= packHigh;
                    end if;

                when packHigh =>
                    srData16(15 downto 8) <= srDataSave;
                    fifoDataReady <= '1';
                    PDSM <= idle;

            end case;
        end if;
    end process;

    -- fifo write 
    FifoWriteStateMachine: process(spiClock, spiReset)  
    begin

        if spiReset = '1' then
            FWSM <= idle;
            fifoWriteEn <= '0';

        elsif rising_edge(spiClock) then
            case FWSM is
            when idle =>
                fifoWriteEn <= '0';
                if fifoDataReady = '1' then
                    FWSM <= write_fifo;
                end if;

            when write_fifo => 
                fifoWriteEn <= '1';
                fifoDataIn  <= srData16;
                FWSM <= check_fullFlag;

            when check_fullFlag =>
                fifoWriteEn <= '0';

                if fifoFull = '1' then
                    readFifo_fromWSM <= '1';
                    FWSM <= holdWrite1;
                else
                    FWSM <= idle;
                end if;

            when holdWrite1 =>
                readFifo_fromWSM <= '0';
                FWSM <= holdWrite2;

            when holdWrite2 =>
                FWSM <= idle;
            
                
            end case;

        end if;

    end process;

    -- fifo read
    FifoReadStateMachine: process(spiClock, spiReset, readFifo_fromSAM) 
    begin

        if spiReset = '1' then
            FRSM <= idle;

        elsif rising_edge(spiClock) then
            case FRSM is

            when idle =>
                fifoReadEn <= '0';
                if    readFifo_fromSAM = '1' and readFifo_fromWSM = '0' then
                      FRSM <= read_fifo;    
                elsif readFifo_fromSAM = '0' and readFifo_fromWSM = '1' then
                      FRSM <= fakeRead;
                elsif readFifo_fromSAM = '1' and readFifo_fromWSM = '1' then
                      FRSM <= futureRead;
                else
                      FRSM <= idle;
                end if;
                    
                
            when read_fifo=>
                fifoReadEn <= '1';
                if readFifo_fromSAM = '0' then
                    FRSM <= idle;
                end if;

            when fakeRead =>
                 fifoReadEn <= '1';
                 FRSM <= idle;   

            when futureRead =>
                FRSM <= idle;
                
            end case;
        end if;
    end process;
                

    debugPort <= srData16;
    debugPortFlags1 <= fifoReadError & fifoWriteError & fifoEmpty & fifoFull;
    debugPortFlags2 <= '0'& fifoDebugPort(2 downto 0);
    debugPortFlags3 <= '0' & fifoDebugPort(10 downto 8);
    debugPortFlags4 <= fifoDebugPort(16) & "0000" & readFifo_fromSAM  & fifoReadEn & fifoWriteEn;
end rtl;





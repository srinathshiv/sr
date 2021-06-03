library ieee;
use ieee.std_logic_1164.all;

entity spi is
    port(
        spiReset    : in std_logic;
        sck         : in std_logic;
        mosi        : in std_logic;
        readData    : in std_logic;

        receiveReg  : out std_logic_vector(7 downto 0);

        controlReg  : in  std_logic_vector(15 downto 0);
        statusReg   : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of spi is 
    -- [1/2] shift register
    component sr is
        port(
        clk     : in  std_logic;
        dataIn  : in  std_logic;
        dataRdy : out std_logic;
        dataOut : out std_logic_vector(7 downto 0)
        );
    end component sr;

    --[2/2] fifo
    component fifo is
        generic(
            addressWidth    : integer := 3 ;
            dataWidth       : integer := 8 ;
            fifoLen         : integer := 8
        );
        port(
            clk     : in  std_logic;
            rst     : in  std_logic;
        
            wren    : in  std_logic;
            din     : in  std_logic_vector(dataWidth-1 downto 0);
        
            rden    : in  std_logic;
            dout    : out std_logic_vector(dataWidth-1 downto 0);
        
            full    : out std_logic;
            empty   : out std_logic;
        
            err     : out std_logic
        );
    end component fifo;

    signal srDataReady  : std_logic;
    signal srData       : std_logic_vector(7 downto 0);
    
    signal fifoWren     : std_logic;
    signal fifoInput    : std_logic_vector(7 downto 0);
    signal fifoRden     : std_logic;
    signal fifoOutput   : std_logic_vector(7 downto 0);
    signal fifoFull     : std_logic;
    signal fifoEmpty    : std_logic;
    signal fifoError    : std_logic;

    type   fifoStates IS(idle, transfer, complete);
    signal fifoWriteState   : fifoStates;
    signal fifoReadState    : fifoStates;

    signal spiControlReg    : std_logic_vector(15 downto 0);
    signal spiStatusReg     : std_logic_vector(15 downto 0);

    signal readReq          : std_logic;
    signal readReqDone      : std_logic;
begin

    sr7: sr port map(
        clk     => sck,
        dataIn  => mosi,
        dataRdy => srDataReady,
        dataOut => srData
    );

    fifo7: fifo port map(
        clk     => sck,
        rst     => spiReset,

        wren    => fifoWren,
        din     => fifoInput,

        rden    => fifoRden,
        dout    => fifoOutput,

        full    => fifoFull,
        empty   => fifoEmpty,
        
        err     => fifoError
    );

    spiControlReg <= controlReg;
    spiStatusReg  <= statusReg;

    readReq     <= spiControlReg(8);
    --fifoRden    <= spiControlReg[9];
    --receiveReg  <= fifoOutput;

    spiStatusReg(2) <= readReqDone;

    --fifo write state machine
    process(sck, spiReset) 

    begin
        if spiReset='1' then
            fifoWriteState <= idle;
            fifoWren <= '0';
        elsif(sck'event and sck='1') then

            case fifoWriteState is
                when idle =>
                     if(srDataReady='0') then
                         fifoWriteState <= transfer;
                     else
                         fifoWriteState <= idle;
                         fifoWren <= '0';
                     end if;

                when transfer =>
                    if(srDataReady='1') then
                        fifoWren        <= '1';
                        fifoInput       <= srData;
                        fifoWriteState  <= complete;
                    else
                        fifoWriteState  <= transfer;
                    end if;
                    
                when complete =>
                     fifoWriteState <= idle;
                     fifoWren       <= '0';
            end case;

        end if;
    end process;

    --fifo read state machine
    process(sck, spiReset) 
    
    begin
        if spiReset = '1' then
            fifoReadState <= idle;
            fifoRden      <= '0';
            readReqDone   <= '0';
        elsif(sck'event and sck='1') then
            case fifoReadState is
                when idle =>
                    if (readReq = '1' and fifoEmpty /= '1') then
                        fifoRden <= '1' ;
                        fifoReadState <= transfer;
                        readReqDone <= '0';
                    else
                        fifoRden <= '0';
                        fifoReadState <= idle;
                        readReqDone <= '0' ;
                    end if;

                when transfer =>
                        fifoRden <= '0';
                        fifoReadState <= complete;
                        readReqDone   <= '0';

                when complete =>
                        fifoRden    <='0';
                        receiveReg  <= fifoOutput;
                        readReqDone <= '1';

                        if(readReq = '0') then
                            fifoReadState <= idle;
                        else  
                            fifoReadState <= complete;
                        end if;
            end case;
        end if;
    end process;

end rtl;
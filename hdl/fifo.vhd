library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--NOTE for fifo design:
-- 1) In this design, for the data to be registered properly in the ram, (write operation)
--    data has to held stable until the falling edge of the clock (plus the hold time of respective flipFlop).
--    read operation doesn't have this constraint.
-- 2) The empty flag is instantaneous, meaning the moment both pointers match, it's pulled high
--    This means when you issue a read for the ultimate data in the RAM, empty flag is pulled up but the read is valid
--    because we can't ignore the ultimate data.
--    So while empty is high, the read error flag is not pulled high, it's pulled high if and only if in the next clock cycle a read is issued
--    (meaning while fifo is empty, a read is issued, the error line is pulled high synchronous to the rising edge of clock)
--
--

--NOTE for dgi spi
-- 3) When the fifo is full, and a write occurs, control logic isses a read whose data is discarded and 
--                                               a write is issued. So the fifo becoming full is not a serious event
--
-- 4) When simulataneous read, write occurs data is read first followed by a write
entity fifo is
    generic(
        FIFOWIDTH   : integer := 16;
        FIFODEPTH   : integer := 8;
        ADDRWIDTH   : integer := 3
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
end entity;

architecture rtl of fifo is

    component ram is
        generic(
            RAMWIDTH  : integer := 16;
            RAMDEPTH  : integer := 8;
            RAMADDR   : integer := 3
        );
        port(
            clock     : in  std_logic;
            writeEn   : in  std_logic;
            readAddr  : in  std_logic_vector( RAMADDR-1 downto 0);
            writeAddr : in  std_logic_vector( RAMADDR-1 downto 0);
            din       : in  std_logic_vector(RAMWIDTH-1 downto 0);
    
            dout      : out std_logic_vector(RAMWIDTH-1 downto 0);
            debugLine : out std_logic
        );
    end component;

    signal readPointer   : std_logic_vector(ADDRWIDTH-1 downto 0) := (others => '0');
    signal writePointer  : std_logic_vector(ADDRWIDTH-1 downto 0) := (others => '0');
    signal read_or_write : std_logic;

    signal RAM_writeAddr : std_logic_vector(ADDRWIDTH-1 downto 0) := (others => '0');
    signal RAM_readAddr  : std_logic_vector(ADDRWIDTH-1 downto 0) := (others => '0');
    signal RAM_writeEn   : std_logic := '0';

    signal fifoWriteHappened : std_logic := '0' ;
begin

    ram0: ram
    port map(
        clock     => clock,
        writeEn   => RAM_writeEn,
        readAddr  => RAM_readAddr,
        writeAddr => RAM_writeAddr,
        din       => dataIn,
        dout      => dataOut,
        debugLine => fifoWriteHappened
    );

    updatePointers: process(clock) begin
    if rising_edge(clock) then
        if reset='1' then
            readPointer   <= (others => '0');
            writePointer  <= (others => '0');
            read_or_write <= '0';

        elsif (writeEn='1') then
            writePointer  <= writePointer + '1';
            read_or_write <= '1';
        
        elsif (readEn='1' and empty='0') then
            readPointer   <= readPointer + '1';
            read_or_write <= '0';

        end if;
    end if;
    end process;
    

    --Set full and empty flags based on read_or_write, readPointer and writePointer signals
    fullEmpty: process(readPointer, writePointer, read_or_write) 
    begin               
    if readPointer = writePointer then
        if read_or_write = '0' then
            full  <= '0';
            empty <= '1';          
        elsif read_or_write = '1' then
            full  <= '1';
            empty <= '0';
        end if;
        
    else
        full  <= '0';
        empty <= '0';
    end if;
    end process;
        
    updateRAM: process(readEn, writeEn, full, empty) begin
        if readEn='0' and writeEn='0' then      
            RAM_writeEn <= '0';
--            readError   <= '0';
--            writeError <= '0';
        
        elsif readEn='1' and writeEn='0' then
            RAM_writeEn <= '0';
--            if empty='1' then
--                readError  <= '1';
--            else
--                readError  <= '0';
--            end if;

        elsif readEn='0' and writeEn='1' then
--            if full = '0' then
                RAM_writeEn <= '1';
--                writeError <= '0';
--            else
--                RAM_writeEn     <= '0';
--                writeError <= '1';
--            end if;
        
        elsif readEn='1' and writeEn='1' then
            if(empty = '0') then  -- When fifo's not empty, we simply read the data and updated read pointer value will be reflected on next raising edge
                                  -- whether fifo is full or empty, write pointer will simply not be updated and writeError signal will be raised
                                  -- The system that uses the fifo should read the writeError signal and raise the writeEn line while pulling down the readEn line
                RAM_writeEn     <= '0';
--                readError   <= '0';
--                writeError  <= '1';
            else -- When it's empty, it defintely means its NOT-FULL meaning we can write. A fifo can't be empty and full at the same time
                RAM_writeEn     <= '1';
--                readError   <= '1';
--                writeError  <= '0';
            end if;
        end if;

    end process;

    errorFlags: process(clock) 
        begin

        if rising_edge(clock) then
            if empty='1' and readEn='1' then
                readError <= '1' ;
            else
                readError <= '0' ;
            end if;

            if full='1' and writeEn='1' then
                writeError <= '1';
            else
                writeError <= '0';
            end if;
        end if;

    end process;

    RAM_readAddr  <= readPointer;
    RAM_writeAddr <= writePointer;

    debugPort(31 downto 24) <= X"00";
    debugPort(23 downto 16) <= "0000000" & fifoWriteHappened;
    debugPort(15 downto 8 ) <= "00000" & writePointer;
    debugPort( 7 downto 0 ) <= "00000" & readPointer;


end rtl;
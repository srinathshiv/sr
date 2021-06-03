library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity fifo is
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
end entity;

architecture rtl of fifo is

    type registerFile is array ( 0 to ( (2**addressWidth)-1 )) of  std_logic_vector(dataWidth-1 downto 0);
    signal mem          : registerFile;

    signal readPtr      : std_logic_vector(addressWidth-1 downto 0);
    signal readPtrNxt   : std_logic_vector(addressWidth-1 downto 0);

    signal writePtr     : std_logic_vector(addressWidth-1 downto 0);
    signal writePtrNxt  : std_logic_vector(addressWidth-1 downto 0);

    signal fullFlag     : std_logic;
    signal fullFlagNxt  : std_logic;

    signal emptyFlag    : std_logic;
    signal emptyFlagNxt : std_logic;

begin
    ---------------------------------------------------------------------------------
    --[1] Initialize pointers and flags
    ---------------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                readPtr     <= (others => '0');
                writePtr    <= (others => '0');
                fullFlag    <= '0';
                emptyFlag   <= '1';
            else
                readPtr     <= readPtrNxt;
                writePtr    <= writePtrNxt;
                fullFlag    <= fullFlagNxt;
                emptyFlag   <= emptyFlagNxt;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------
    --[2] Update pointers and flags
    ---------------------------------------------------------------------------------
    process(wren, rden, writePtr, readPtr, emptyFlag, fullFlag)
    begin
        writePtrNxt     <= writePtr;   -- something changes on enable lines, 
        readPtrNxt      <= readPtr;    -- so save the current state of pointers
        fullFlagNxt     <= fullFlag;
        emptyFlagNxt    <= emptyFlag;

        if(wren='1' and rden='0') then
            if(fullFlag = '0') then
                if( conv_integer(writePtr) < (fifoLen-1) ) then
                    writePtrNxt  <= writePtr+1;
                    emptyFlagNxt <= '0';
                else
                    writePtrNxt  <= (others => '0');
                    emptyFlagNxt <= '0';
                end if;

                if( (conv_integer(writePtr) = (fifoLen-1) and conv_integer(readPtr)=0) or conv_integer(writePtr+'1') = conv_integer(readPtr)) then
                    fullFlagNxt <= '1';
                end if;
            end if;
        end if;
        
        if(wren='0' and rden='1') then
            if(emptyFlag='0') then
                if(conv_integer(readPtr) < (fifoLen-1) ) then
                    readPtrNxt <= readPtr+1;
                    fullFlagNxt <= '0';
                else
                    readPtrNxt <= (others => '0');
                    fullFlagNxt <= '0';
                end if;

                if( (conv_integer(readPtr) = (fifoLen-1) and conv_integer(writePtr)=0) or conv_integer(readPtr+'1') = conv_integer(writePtr)) then
                    emptyFlagNxt <= '1';
                end if;
            end if;
        end if;

        if(wren='1' and rden='1') then
            if( conv_integer(writePtr) < fifoLen-1) then
                writePtrNxt <= writePtr + 1;
            else
                writePtrNxt <= (others=>'0');
            end if;

            if( conv_integer(readPtr) < fifoLen-1) then
                readPtrNxt <= readPtr + 1;
            else
                readPtrNxt <= (others=>'0');
            end if;
        end if;

    end process;

    ---------------------------------------------------------------------------------
    --[3] Update memory based on pointers and flags
    ---------------------------------------------------------------------------------
    process(clk) 

    begin
        if rising_edge(clk) then
            if(wren='1' and fullFlag='0') then
                mem( conv_integer(writePtr) ) <= din;
            elsif(wren='1' and fullFlag='1') then
                err <= '1';
            end if;

            if(rden='1' and emptyFlag='0') then
                dout <= mem( conv_integer(readPtr));
            elsif(rden='1' and emptyFlag='1') then
                err <= '1';
            end if;
        end if;
    end process;

    full    <= fullFlag;
    empty   <= emptyFlag;

end rtl;
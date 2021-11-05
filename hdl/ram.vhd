library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ram is
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
end entity;

architecture rtl of ram is
    
    type memStruct is array (RAMDEPTH-1 downto 0) of 
            std_logic_vector(RAMWIDTH-1 downto 0);
    signal singlePortRam : memStruct;
    signal dl : std_logic := '0';

begin

    process(clock) 
    
    begin

        if falling_edge(clock) then
            if(writeEn) then
                singlePortRam( conv_integer(writeAddr) ) <= din;
                dl <= not dl ;
            end if;
        end if;
        
    end process; 

    debugLine <= dl;
    dout <= singlePortRam( conv_integer(readAddr) );

end rtl;
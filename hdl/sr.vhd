library ieee;
use ieee.std_logic_1164.all;

entity sr is
generic(
    SRWIDTH   : integer := 8
);
port (
    reset     : in  std_logic;
    clock     : in  std_logic;
    enable    : in  std_logic;
    dataIn    : in  std_logic;
    dataReady : out std_logic;
    dataOut   : out std_logic_vector(SRWIDTH-1 downto 0)
);
end sr;

architecture rtl of sr is
    signal   shiftReg   : std_logic_vector(SRWIDTH-1 downto 0) := (others => '0');
begin

    process(clock, reset, enable)
        variable rxCount : integer range 0 to SRWIDTH := 0;
    begin
        if reset = '1' then
            shiftReg   <= X"00";
            dataReady  <= '0';
            rxCount    :=  0 ;

        elsif enable = '0' then
            if (rxCount < SRWIDTH) then
                if rising_edge(clock) then
                    shiftReg <= shiftReg(SRWIDTH-2 downto 0) & dataIn;
                    rxCount  := rxCount + 1;
                end if;
        
            else
                dataOut   <= shiftReg;
                dataReady <= '1';
                rxCount   := 0;
            end if;
        
        else
            dataReady <= '0';
            rxCount   :=  0 ;
        end if;
    end process;

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity sr is
port (
    clk     : in  std_logic;
    dataIn  : in  std_logic;
    dataRdy : out std_logic;
    dataOut : out std_logic_vector(7 downto 0)
);
end sr;

architecture rtl of sr is
    signal   shReg   : std_logic_vector(7 downto 0) := (others => '0');
begin

    process(clk)
        variable rxCount : integer range 0 to 8 := 0;
    begin

        if (rxCount<8) then
            if rising_edge(clk) then
                shReg   <= shReg(6 downto 0) & dataIn;
                dataRdy <= '0';
                rxCount := rxCount + 1;
            end if;
        
        else
            dataOut <= shReg;
            dataRdy <= '1';
            rxCount := 0;
        end if;
    end process;

end rtl;

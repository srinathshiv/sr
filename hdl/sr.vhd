library ieee;
use ieee.std_logic_1164.all;

entity sr is
port (
    clk     : in  std_logic;
    dataIn  : in  std_logic;
    dataOut : out std_logic_vector(7 downto 0)
);
end sr;

architecture rtl of sr is
    signal   shReg   : std_logic_vector(7 downto 0) := (others => '0');

begin

    process(clk)

    begin
        if rising_edge(clk) then
            shReg <= shReg(6 downto 0) & dataIn;
        end if;
    end process;

dataOut <= shReg;

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity tbsr is
end tbsr;

architecture rtl of tbsr is

    component sr
    port (
        clk     : in  std_logic;
        dataIn  : in  std_logic;
        dataOut : out std_logic_vector(7 downto 0)
    );
    end component;

    constant tclk_period : time := 500 ns;
    signal tclk : std_logic := '0';
    signal din  : std_logic := '0';
    signal dout : std_logic_vector(7 downto 0);
begin

    sr0: sr port map(
        clk     => tclk,
        dataIn  => din,
        dataOut => dout
    );

    process begin
    wait for 200 ns;

    -- data: 0xB1
    din <= '1';
    wait for 500 ns;
    
    din <= '0';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;

    din <= '0';
    wait for 500 ns;

    din <= '0';
    wait for 500 ns;

    din <= '0';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;
    
    -- data : 0xF3
    din <= '1';
    wait for 500 ns;
    
    din <= '1';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;

    din <= '0';
    wait for 500 ns;

    din <= '0';
    wait for 500 ns;

    din <= '1';
    wait for 500 ns;

    din <= '1';
    wait for 300 ns;

    end process;

    tclk <= not tclk after (tclk_period/2.0);
end rtl;

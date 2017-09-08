-------------------------------------------------------------------[11.01.2017]
-- Sync
-------------------------------------------------------------------------------
-- Engineer: MVV <mvvproject@gmail.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.STD_LOGIC_ARITH.all;

entity vga_sync is port (
    I_CLK       : in std_logic;             -- VGA dot clock
    I_RESET     : in std_logic;
    I_EN        : in std_logic;
    O_HCNT      : out std_logic_vector(9 downto 0);
    O_VCNT      : out std_logic_vector(9 downto 0);
    O_FLASH     : out std_logic;            -- частота мерцания курсора
    O_BLANK     : out std_logic;
    O_HSYNC     : out std_logic;            -- horizontal (line) sync
    O_VSYNC     : out std_logic);           -- vertical (frame) sync
end entity;

architecture rtl of vga_sync is

-- ModeLine "640x480@60Hz"  25,175 640 656 752 800 480 490 492 525 -HSync -VSync
    -- Horizontal Timing constants  
    constant h_pixels_across    : integer := 640 - 1;
    constant h_sync_on      : integer := 656 - 1;
    constant h_sync_off     : integer := 752 - 1;
    constant h_end_count        : integer := 800 - 1;
    -- Vertical Timing constants
    constant v_pixels_down      : integer := 480 - 1;
    constant v_sync_on      : integer := 490 - 1;
    constant v_sync_off     : integer := 492 - 1;
    constant v_end_count        : integer := 525 - 1;
    constant h_offset : integer := 2;

    signal h            : std_logic_vector(9 downto 0) := "0000000000";     -- horizontal pixel counter
    signal hcnt         : std_logic_vector(9 downto 0) := "0000000000";     -- horizontal pixel counter
    signal vcnt         : std_logic_vector(9 downto 0) := "0000000000";     -- vertical line counter
    signal hsync            : std_logic;
    signal vsync            : std_logic;
    signal blank            : std_logic;
    signal counter          : std_logic_vector(23 downto 0);
    signal next_hend      : std_logic := '0';
    signal next_vend      : std_logic := '0';
    
begin
        
    process (I_CLK, I_RESET, I_EN, hcnt, vcnt)
    begin
        if rising_edge(I_CLK) then
            if I_RESET = '1' then
                hcnt <= (others => '0');
                vcnt <= (others => '0');
                counter <= (others => '0');
            elsif I_EN = '1' then
                
                if hcnt = h_end_count then
                    hcnt <= (others => '0');

                    if vcnt = v_end_count then
                        vcnt <= (others => '0');
                    else
                        vcnt <= vcnt + 1;
                    end if;
                else 
                    hcnt <= hcnt + 1;
                end if;                
                counter <= counter + 1;
            end if;
        end if;
    end process;

    hsync   <= '1' when (hcnt <= h_sync_on) or (hcnt > h_sync_off) else '0';
    vsync   <= '1' when (vcnt <= v_sync_on) or (vcnt > v_sync_off) else '0';
    blank   <= '1' when (hcnt <= h_offset or hcnt > h_pixels_across + h_offset) or (vcnt > v_pixels_down) else '0';

    O_HCNT  <= hcnt;
    O_VCNT  <= vcnt;
    O_FLASH <= counter(23);
    O_HSYNC <= hsync;
    O_BLANK <= blank;
    O_VSYNC <= vsync;

end architecture;
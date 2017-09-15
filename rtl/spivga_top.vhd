library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spivga_top is
    port(
        -- master clock 50.0 MHz
        CLK_50MHZ   : in std_logic;

        -- HDMI
        TMDS        : out std_logic_vector(7 downto 0);

        -- USB Host (VNC2-32)
        USB_NRESET  : in std_logic;
        USB_TX      : in std_logic;
        USB_IO1     : in std_logic;

        -- SPI (W25Q64/SD)
        DATA0       : in std_logic;
        ASDO        : out std_logic;
        DCLK        : out std_logic;
        NCSO        : out std_logic;

        -- I2C (HDMI/RTC)
        I2C_SCL     : inout std_logic;
        I2C_SDA     : inout std_logic;

        -- SD
        SD_NDET     : in std_logic;
        SD_NCS      : out std_logic;
        SD_SO       : in std_logic;
        SD_SI       : out std_logic;
        SD_CLK      : out std_logic;

        -- Ethernet (ENC424J600)
        ETH_SO      : in std_logic;
        ETH_NINT    : in std_logic;
        ETH_NCS     : out std_logic;

        -- SDRAM (32M16)
        SDRAM_DQ    : inout std_logic_vector(15 downto 0);
        SDRAM_A     : out std_logic_vector(12 downto 0);
        SDRAM_BA    : out std_logic_vector(1 downto 0);
        SDRAM_DQML  : out std_logic;
        SDRAM_DQMH  : out std_logic;
        SDRAM_CLK   : out std_logic;
        SDRAM_NWE   : out std_logic;
        SDRAM_NCAS  : out std_logic;
        SDRAM_NRAS  : out std_logic;

        -- Ext SPI
        SPI_SCLK      : in std_logic;
        SPI_VGA_NCS   : in std_logic;
        SPI_SD_NCS    : in std_logic;
        SPI_FLASH_NCS : in std_logic;
        SPI_SI        : in std_logic;
        SPI_SO        : out std_logic

    );
end spivga_top;

architecture rtl of spivga_top is
    
    signal reset : std_logic;
    signal areset : std_logic;
    signal locked0 : std_logic;

    signal clk_vga : std_logic;
    signal clk_tmds : std_logic;
    signal clk_spi : std_logic;

    signal vga_hsync: std_logic;
    signal vga_vsync: std_logic;
    signal vga_blank : std_logic;
    signal vga_r : std_logic_vector(7 downto 0);
    signal vga_g : std_logic_vector(7 downto 0);
    signal vga_b : std_logic_vector(7 downto 0);

    signal kb_key0 : std_logic_vector(7 downto 0);
    signal kb_key1 : std_logic_vector(7 downto 0);
    signal kb_key2 : std_logic_vector(7 downto 0);
    signal kb_fkeys     : std_logic_vector(12 downto 1) := "000000000000";

    signal spi_vga_so : std_logic;

begin

    U_PLL: entity work.altpll0
        port map (
            areset      => '0',
            locked      => locked0,
            inclk0      => CLK_50MHZ,   --  50.00 MHz
            c0          => clk_vga,     --  25.20 MHz
            c1          => clk_tmds,    -- 126.00 MHz
            c2          => open,        --  28.00 MHz
            c3          => open,        --  84.00 MHz
            c4          => clk_spi);    --   8.00 MHz

    U_HDMI: entity work.hdmi
        generic map (
            FREQ        => 25200000,
            FS          => 48000,
            CTS         => 25200,
            N           => 6144)
        port map (
            I_CLK_VGA   => clk_vga,
            I_CLK_TMDS  => clk_tmds,
            I_HSYNC     => vga_hsync,
            I_VSYNC     => vga_vsync,
            I_BLANK     => vga_blank,
            I_RED       => vga_r,
            I_GREEN     => vga_g,
            I_BLUE      => vga_b,
            I_AUDIO_PCM_L   => "0000000000000000",
            I_AUDIO_PCM_R   => "0000000000000000",
            O_TMDS      => TMDS);

    U_HID: entity work.deserializer
    generic map (
        divisor         => 434)     -- divisor = 50MHz / 115200 Baud = 434
    port map(
        I_CLK           => CLK_50MHZ,
        I_RESET         => areset,
        I_RX            => USB_TX,
        I_NEWFRAME      => USB_IO1,
        I_ADDR          => "11111111",
        O_MOUSE0_X      => open,
        O_MOUSE0_Y      => open,
        O_MOUSE0_Z      => open,
        O_MOUSE0_BUTTONS    => open,
        O_MOUSE1_X      => open,
        O_MOUSE1_Y      => open,
        O_MOUSE1_Z      => open,
        O_MOUSE1_BUTTONS    => open,
        O_KEY0          => kb_key0,--kb_key0,
        O_KEY1          => kb_key1,--kb_key1,
        O_KEY2          => kb_key2,--kb_key2,
        O_KEY3          => open,--kb_key3,
        O_KEY4          => open,--kb_key4,
        O_KEY5          => open,--kb_key5,
        O_KEY6          => open,--kb_key6,
        O_KEYBOARD_SCAN     => open,
        O_KEYBOARD_FKEYS    => kb_fkeys,
        O_KEYBOARD_JOYKEYS  => open,
        O_KEYBOARD_CTLKEYS  => open);

    U_SPIVGA: entity work.spivga
    port map(
            reset       => reset,
            clk_vga     => clk_vga,
            clk_spi     => clk_spi,

            vga_r       => vga_r,
            vga_g       => vga_g,
            vga_b       => vga_b,
            vga_hsync   => vga_hsync,
            vga_vsync   => vga_vsync,
            vga_blank   => vga_blank,

            kb_key0     => kb_key0,
            kb_key1     => kb_key1,
            kb_key2     => kb_key2,
            kb_fkeys    => kb_fkeys,

            spi_sclk    => SPI_SCLK,
            spi_ncs     => SPI_VGA_NCS,
            spi_si      => SPI_SI,
            spi_so      => spi_vga_so
        );

    -----------------------------------------------------------------------------------------------

    areset  <= not locked0; -- reset
    reset   <= kb_fkeys(4) or areset;   -- hot reset

    -- sd card
    SD_CLK <= SPI_SCLK;
    SD_SI  <= SPI_SI;
    SD_NCS <= SPI_SD_NCS;

    -- flash
    NCSO   <= SPI_FLASH_NCS;
    DCLK   <= SPI_SCLK;
    ASDO  <= SPI_SI;

    -- slave output selector
    SPI_SO <= SD_SO when SPI_SD_NCS = '0' else 
              DATA0 when SPI_FLASH_NCS = '0' else 
              spi_vga_so when SPI_VGA_NCS = '0' else 
              'Z';

    ETH_NCS <= '1'; -- disable Ethernet controller
    SDRAM_NWE <= '1'; -- disable sdram
    SDRAM_NCAS <= '1';
    SDRAM_NRAS <= '1';
    SDRAM_CLK <= '0';
    I2C_SCL <= 'Z'; -- disable i2c
    I2C_SDA <= 'Z';

end rtl;

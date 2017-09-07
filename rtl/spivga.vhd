library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spivga is
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
        SPI_SCLK    : in std_logic;
        SPI_NCS     : in std_logic;
        SPI_SI      : in std_logic;
        SPI_SO      : out std_logic

    );
end spivga;

architecture rtl of spivga is
    
    component rom_font
    port (
        address : in std_logic_vector(11 downto 0);
        clock   : in std_logic;
        q       : out std_logic_vector(7 downto 0)
    );
    end component;

    component screen2
    port (
        data    : in std_logic_vector(15 downto 0);
        rdaddress : in std_logic_vector(11 downto 0);
        rdclock  : in std_logic;
        wraddress : in std_logic_vector(11 downto 0);
        wrclock   : in std_logic;
        wren      : in std_logic;
        q         : out std_logic_vector(15 downto 0)
    );
    end component;

    signal reset : std_logic;
    signal areset : std_logic;
    signal locked0 : std_logic;

    signal clk_vga : std_logic;
    signal clk_tmds : std_logic;
    signal clk_spi : std_logic;

    signal video_on : std_logic;
    signal pixel_x: std_logic_vector(9 downto 0) := "0000000000";
    signal pixel_y: std_logic_vector(9 downto 0) := "0000000000";

    signal char: std_logic_vector(7 downto 0);
    signal attr: std_logic_vector(7 downto 0);

    signal char_x: std_logic_vector(2 downto 0);
    signal char_y: std_logic_vector(3 downto 0);

    signal rom_addr: std_logic_vector(11 downto 0);
    signal row_addr: std_logic_vector(3 downto 0);
    signal bit_addr: std_logic_vector(2 downto 0);
    signal font_word: std_logic_vector(7 downto 0);
    signal font_bit: std_logic;
    
    signal addr_read: std_logic_vector(11 downto 0);
    signal addr_write: std_logic_vector(11 downto 0);
    signal vram_di: std_logic_vector(15 downto 0);
    signal vram_do: std_logic_vector(15 downto 0);
    signal vram_wr: std_logic := '0';

    signal hsync: std_logic;
    signal vsync: std_logic;
    signal pixel_tick: std_logic;

    signal vga_r : std_logic_vector(7 downto 0);
    signal vga_g : std_logic_vector(7 downto 0);
    signal vga_b : std_logic_vector(7 downto 0);

    signal spi_do : std_logic_vector(23 downto 0);
    signal spi_do_valid : std_logic;

    signal kb_key0 : std_logic_vector(7 downto 0);
    signal kb_key1 : std_logic_vector(7 downto 0);
    signal kb_key2 : std_logic_vector(7 downto 0);

    signal kb_fkeys     : std_logic_vector(12 downto 1);

    signal inc_address : std_logic := '0';

    signal clear : std_logic := '0';
    signal addr_clear: std_logic_vector(11 downto 0);

    signal flash : std_logic;
    signal is_flash : std_logic;
    signal blank : std_logic;
    signal rgb_fg : std_logic_vector(5 downto 0);
    signal rgb_bg : std_logic_vector(5 downto 0);
    signal rgb    : std_logic_vector(5 downto 0);

    signal selector : std_logic_vector(3 downto 0);

    signal tone : std_logic := '0';
    signal tone_note : std_logic_vector(7 downto 0);
    signal tone_len : std_logic_vector(7 downto 0);

    signal state : std_logic_vector(2 downto 0) := "000";    

    signal test : std_logic := '0';

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


    U_SYNC: entity work.vga_sync
        port map (
            I_CLK       => clk_vga,
            I_RESET     => reset,
            I_EN        => '1',
            O_HCNT      => pixel_x,
            O_VCNT      => pixel_y,
            O_FLASH     => flash,
            O_BLANK     => blank,
            O_HSYNC     => hsync,
            O_VSYNC     => vsync
        ); 


    --U_FONT: entity work.font_rom
    --    port map(
    --        clock       => clk_vga,
    --        addr        => rom_addr,
    --        data        => font_word
    --    );

    --U_VRAM: entity work.ram
    --    port map (
    --        address_a   => addr_write,
    --        clock_a     => clk_spi,
    --        data_a      => vram_di,
    --        wren_a      => vram_wr,
    --        q_a         => open,

    --        address_b   => addr_read,
    --        clock_b     => clk_vga,
    --        data_b      => (others => '0'),
    --        wren_b      => '0',
    --        q_b         => vram_do
    --    );

    U_FONT: rom_font
    port map (
        address => rom_addr,
        clock   => clk_vga,
        q       => font_word
    );

    U_VRAM: screen2 
    port map (
        data    => vram_di,
        rdaddress => addr_read,
        rdclock   => clk_vga,
        wraddress => addr_write,
        wrclock   => clk_spi,
        wren      => vram_wr,
        q         => vram_do
    );

    U_HDMI: entity work.hdmi
        generic map (
            FREQ        => 25200000,
            FS          => 48000,
            CTS         => 25200,
            N           => 6144)
        port map (
            I_CLK_VGA   => clk_vga,
            I_CLK_TMDS  => clk_tmds,
            I_HSYNC     => hsync,
            I_VSYNC     => vsync,
            I_BLANK     => blank,
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

    U_SPI: entity work.spi_slave
    generic map(
        N              => 24        
    )
    port map(
        clk_i          => clk_spi,
        spi_sck_i      => SPI_SCLK,
        spi_ssel_i     => SPI_NCS,
        spi_mosi_i     => SPI_SI,
        spi_miso_o     => SPI_SO,

        di_req_o       => open,
        di_i           => kb_key0 & kb_key1 & kb_key2,
        wren_i         => '1',
        do_valid_o     => spi_do_valid,
        do_o           => spi_do,

        do_transfer_o  => open,
        wren_o         => open,
        wren_ack_o     => open,
        rx_bit_reg_o   => open,
        state_dbg_o    => open
        );

    -----------------------------------------------------------------------------------------------

    areset  <= not locked0; -- reset
    reset   <= kb_fkeys(4) or areset;   -- hot reset

    video_on <= not blank;
    char_x <= pixel_x(2 downto 0);
    char_y <= pixel_y(3 downto 0);

    -- read memory and font data
    process(clk_vga, pixel_x)
    begin
        if rising_edge(clk_vga) then
            case pixel_x(2 downto 0) is
                -- read video memory
                when "000" => addr_read <= pixel_y(8 downto 4) & pixel_x(9 downto 3);
                -- reading font glyph
                when "001" => 
                        char <= vram_do(15 downto 8); 
                        attr <= vram_do(7 downto 0); 
                        rom_addr <= char & char_y;
                when others => null;
            end case;
        end if;
    end process;

    -- getting font pixel (with delay of 2 cycles)
    bit_addr <= char_x(2 downto 0);
    process (clk_vga)
    begin
        if rising_edge(clk_vga) then
            case bit_addr is 
                when "000" => font_bit <= font_word(2);
                when "001" => font_bit <= font_word(1);
                when "010" => font_bit <= font_word(0);
                when "011" => font_bit <= font_word(7);
                when "100" => font_bit <= font_word(6);
                when "101" => font_bit <= font_word(5);
                when "110" => font_bit <= font_word(4);
                when "111" => font_bit <= font_word(3);
            end case;
        end if;
    end process;

    -- rgb multiplexing
    is_flash <= '1' when attr(3 downto 0) = "0001" else '0';
    selector <= video_on & font_bit & flash & is_flash;
    rgb_fg <= (attr(7) and attr(4)) & attr(7) & (attr(6) and attr(4)) & attr(6) & (attr(5) and attr(4)) & attr(5);
    rgb_bg <= (attr(3) and attr(0)) & attr(3) & (attr(2) and attr(0)) & attr(2) & (attr(1) and attr(0)) & attr(1);
    rgb <= rgb_fg when (selector="1111" or selector="1001" or selector="1100" or selector="1110") else 
           rgb_bg when (selector="1011" or selector="1101" or selector="1000" or selector="1010") else 
           (others => '0');

    vga_r <= rgb(5 downto 4) & rgb(5 downto 4) & rgb(5 downto 4) & rgb(5 downto 4);
    vga_g <= rgb(3 downto 2) & rgb(3 downto 2) & rgb(3 downto 2) & rgb(3 downto 2);
    vga_b <= rgb(1 downto 0) & rgb(1 downto 0) & rgb(1 downto 0) & rgb(1 downto 0);

    -- read spi commands and process incoming data
    --0x01 = CMD_CLEAR - 0 - 0
    --0x02 = CMD_SET_POS - X - Y (0...79, 0...29)
    --0x04 = CMD_CHAR - CHAR - ATTRS    

    -- test
    --process(reset, clk_spi)
    --begin
    --    if rising_edge(clk_spi) then
    --        if (reset = '1') then
    --            vram_wr <= '0';
    --            addr_write <= (others => '0');
    --        elsif addr_write < 4095 then
    --            vram_wr <= '1';
    --            case addr_write is
    --                when "000000000000" => vram_di <= X"48F2";
    --                when "000000000001" => vram_di <= X"45F2";
    --                when "000000000010" => vram_di <= X"4CF2";
    --                when "000000000011" => vram_di <= X"4CF2";
    --                when others => vram_di <= X"2DF0";
    --            end case;
    --            addr_write <= addr_write + 1;
    --        else 
    --            vram_wr <= '0';
    --        end if;
    --    end if;
    --end process;

    --process(reset, clk_spi, spi_do_valid, spi_do, addr_write, addr_clear, clear)
    --begin
    --    if (rising_edge(clk_spi)) then
    --        if (reset = '1') then
    --            addr_write <= (others => '0');
    --            inc_address <= '0';
    --            vram_wr <= '0';
    --            clear <= '0';
    --            addr_clear <= (others => '0');
    --        elsif (spi_do_valid = '1' and clear = '0') then
    --            case spi_do(23 downto 16) is 
    --                when X"01"  => vram_wr <= '0'; clear <= '1'; addr_clear <= (others => '0');
    --                when X"02"  => vram_wr <= '0'; addr_write <= spi_do(14 downto 8) & spi_do(4 downto 0); -- y: 0...29, x: 0...79
    --                when X"04"  => vram_wr <= '1'; vram_di    <= spi_do(15 downto 0); inc_address <= '1'; -- char + attrs, inc address
    --                --when X"08"  => vram_wr <= '0'; tone <= '1'; tone_note <= spi_do(15 downto 8); tone_len <= spi_do(7 downto 0);
    --                when others => vram_wr <= '0';
    --            end case;
    --        elsif (spi_do_valid = '0' and clear = '0') then 
    --            vram_wr <= '0';
    --            -- do the address increment for next write
    --            if (inc_address = '1') then
    --                addr_write <= addr_write + 1;
    --                -- new row jump
    --                if (addr_write(4 downto 0) >= 80) then
    --                    addr_write(4 downto 0) <= "00000";
    --                    addr_write(11 downto 5) <= addr_write(11 downto 5) + 1;
    --                end if;
    --                inc_address <= '0';
    --            end if;
    --            -- tone play
    --            if (tone = '1') then 
    --                -- todo
    --                -- tone_note;
    --                -- tone_len;
    --                tone <= '0';
    --            end if;
    --        elsif (clear = '1') then
    --            vram_wr <= '1';
    --            vram_di <= (others => '0');
    --            addr_write <= addr_clear;
    --            if (addr_clear < 2400) then 
    --                addr_clear <= addr_clear + 1;
    --            else 
    --                clear <= '0';
    --                addr_clear <= (others => '0');
    --                addr_write <= (others => '0');
    --            end if;
    --        end if;
    --    end if;
    --end process;

    ETH_NCS <= '1'; -- disable Ethernet controller
    SD_NCS <= '1'; -- disable SD card
    NCSO <= '1'; -- disable spi flash
    SDRAM_NWE <= '1'; -- disable sdram
    SDRAM_NCAS <= '1';
    SDRAM_NRAS <= '1';
    SDRAM_CLK <= '0';
    I2C_SCL <= 'Z'; -- disable i2c
    I2C_SDA <= 'Z';

end rtl;

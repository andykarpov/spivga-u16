library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spivga is
    port(

        reset       : in std_logic;

        clk_vga     : in std_logic;
        clk_spi     : in std_logic;

        vga_r       : out std_logic_vector(7 downto 0);
        vga_g       : out std_logic_vector(7 downto 0);
        vga_b       : out std_logic_vector(7 downto 0);
        vga_hsync   : out std_logic;
        vga_vsync   : out std_logic;
        vga_blank   : out std_logic;

        kb_key0     : in std_logic_vector(7 downto 0);
        kb_key1     : in std_logic_vector(7 downto 0);
        kb_key2     : in std_logic_vector(7 downto 0);
        kb_fkeys    : in std_logic_vector(12 downto 1);

        spi_sclk    : in std_logic;
        spi_ncs     : in std_logic;
        spi_si      : in std_logic;
        spi_so      : out std_logic
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

    signal video_on : std_logic;
    signal pixel_x: std_logic_vector(9 downto 0) := "0000000000";
    signal pixel_y: std_logic_vector(9 downto 0) := "0000000000";

    signal char: std_logic_vector(7 downto 0);
    signal attr, last_attr, cur_attr: std_logic_vector(7 downto 0);

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

    signal spi_do : std_logic_vector(23 downto 0);
    signal spi_do_valid : std_logic;

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

    signal font_reg : std_logic_vector(7 downto 0);

begin

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

    U_SPI: entity work.spi_slave
    generic map(
        N              => 24        
    )
    port map(
        clk_i          => clk_spi,
        spi_sck_i      => spi_sclk,
        spi_ssel_i     => spi_ncs,
        spi_mosi_i     => spi_si,
        spi_miso_o     => spi_so,

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

    video_on <= not blank;

    char_x <= pixel_x(2 downto 0);
    char_y <= pixel_y(3 downto 0);

    addr_read <= (pixel_y(8 downto 4) & pixel_x(9 downto 3));
    char <= vram_do(15 downto 8); 
    cur_attr <= vram_do(7 downto 0); 
    rom_addr <= char & char_y;
    font_reg <= font_word;

    process(clk_vga, bit_addr)
    begin
        if rising_edge(clk_vga) then
            if (bit_addr = "010") then
                last_attr <= cur_attr;
            end if;
        end if;
    end process;

    attr <= last_attr when bit_addr <= 1 else cur_attr;

    -- getting font pixel of the current char line
    bit_addr <= char_x(2 downto 0);
    font_bit <= font_reg(1) when bit_addr = "000" else 
                font_reg(0) when bit_addr = "001" else 
                font_reg(7) when bit_addr = "010" else 
                font_reg(6) when bit_addr = "011" else 
                font_reg(5) when bit_addr = "100" else 
                font_reg(4) when bit_addr = "101" else 
                font_reg(3) when bit_addr = "110" else 
                font_reg(2) when bit_addr = "111";

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
    vga_hsync <= hsync;
    vga_vsync <= vsync;
    vga_blank <= blank;

    -- read spi commands and process incoming data
    --0x01 = CMD_CLEAR - 0 - 0
    --0x02 = CMD_SET_POS - X - Y (0...79, 0...29)
    --0x04 = CMD_CHAR - CHAR - ATTRS    

    process(reset, clk_spi, spi_do_valid, spi_do, addr_write, addr_clear, clear)
    begin
        if (rising_edge(clk_spi)) then
            if (reset = '1') then
                addr_write <= (others => '0');
                inc_address <= '0';
                vram_wr <= '0';
                clear <= '0';
                addr_clear <= (others => '0');
            elsif (spi_do_valid = '1' and clear = '0') then
                case spi_do(23 downto 16) is 
                    when X"01"  => vram_wr <= '0'; clear <= '1'; addr_clear <= (others => '0');
                    when X"02"  => vram_wr <= '0'; addr_write <= spi_do(14 downto 8) & spi_do(4 downto 0); -- y: 0...29, x: 0...79
                    when X"04"  => vram_wr <= '1'; vram_di    <= spi_do(15 downto 0); inc_address <= '1'; -- char + attrs, inc address
                    --when X"08"  => vram_wr <= '0'; tone <= '1'; tone_note <= spi_do(15 downto 8); tone_len <= spi_do(7 downto 0);
                    when others => vram_wr <= '0';
                end case;
            elsif (spi_do_valid = '0' and clear = '0') then 
                vram_wr <= '0';
                -- do the address increment for next write
                if (inc_address = '1') then
                    addr_write <= addr_write + 1;
                    -- new row jump
                    if (addr_write(4 downto 0) >= 80) then
                        addr_write(4 downto 0) <= "00000";
                        addr_write(11 downto 5) <= addr_write(11 downto 5) + 1;
                    end if;
                    inc_address <= '0';
                end if;
                -- tone play
                if (tone = '1') then 
                    -- todo
                    -- tone_note;
                    -- tone_len;
                    tone <= '0';
                end if;
            elsif (clear = '1') then
                vram_wr <= '1';
                vram_di <= (others => '0');
                addr_write <= addr_clear;
                if (addr_clear < 2400) then 
                    addr_clear <= addr_clear + 1;
                else 
                    clear <= '0';
                    addr_clear <= (others => '0');
                    addr_write <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end rtl;

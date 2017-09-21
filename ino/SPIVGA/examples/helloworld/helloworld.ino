/**
 * Example sketch to print Hello World on the SPIVGA display
 */
#include <Arduino.h>
#include <SPIVGA.h>
#include <SPI.h>

#define SPI_VGA_CS 10
#define SPI_SD_CS  9
#define SPI_FLASH_CS  8

SPIVGA vga(SPI_VGA_CS);
KeyboardReport report;

void setup()
{
    pinMode(SPI_SD_CS, OUTPUT);
    digitalWrite(SPI_SD_CS, HIGH);

    pinMode(SPI_VGA_CS, OUTPUT);
    digitalWrite(SPI_VGA_CS, HIGH);

    pinMode(SPI_FLASH_CS, OUTPUT);
    digitalWrite(SPI_FLASH_CS, HIGH);
  
    SPI.begin();
    vga.begin();
    vga.setColor(vga.COLOR_WHITE);
    vga.setBackground(vga.COLOR_BLACK);
    vga.clear();
    vga.setPos(0,0);
    vga.print(F("Hello world!"));
}

void loop()
{
    vga.noop();
    report = vga.getReport();
    if (report.key1 != 0x00) {
        vga.setColor(vga.COLOR_GREEN_I);
        vga.setPos(10,10);
        vga.print(F("Key pressed: "));
        vga.print(report.key1);
        vga.print(F("  "));
    } else {
        vga.setColor(vga.COLOR_RED_I);
        vga.setPos(10,10);
        vga.print(F("Key up           "));
    }
    delay(100);
}

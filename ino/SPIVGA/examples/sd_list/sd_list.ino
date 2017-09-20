/**
 * Example sketch to print list of files on SD card on the SPIVGA display
 */
#include <Arduino.h>
#include <SPIVGA.h>
#include <SPI.h>
#include <SD.h>

#define SPI_VGA_CS 10
#define SPI_SD_CS  9
#define SPI_FLASH_CS  8
#define SERIAL_SPEED 9600

SPIVGA vga(SPI_VGA_CS);
KeyboardReport report;
File root;
uint8_t tick = 0;

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

    vga.setBackground(vga.COLOR_BLUE);
    vga.fill(10, 5, 69, 24, 0);
    vga.frame(10, 5, 69, 24, 1);
    vga.setPos(65, 5);
    vga.print(F("["));
    vga.write(254);
    vga.print(F("]"));
    vga.setPos(12,5);
    vga.print(F("[Test listing files on SD card]"));

    vga.setPos(20, 10);
    vga.print(F("Init SD Card... "));

    if (!SD.begin(SPI_SD_CS)) {
      vga.setColor(vga.COLOR_RED_I);
      vga.print(F("FAILED"));
      return;
    }
    vga.setColor(vga.COLOR_GREEN_I);
    vga.print(F("DONE"));
    vga.setColor(vga.COLOR_WHITE);

    root = SD.open("/");
    printDirectory(root);

    vga.setPos(21, 22);
    vga.setColor(vga.COLOR_WHITE);
    vga.setBackground(vga.COLOR_RED_I);
    vga.print(F("      Press ENTER to continue...      "));
}

void printDirectory(File dir) {
  int i = 0;
  while (true) {

    File entry =  dir.openNextFile();
    if (! entry) {
      // no more files
      break;
    }
    vga.setPos(21, i+11);
    if (i==8) {
      vga.setBackground(vga.COLOR_BLUE);
      vga.setColor(vga.COLOR_YELLOW_I);
      vga.print(F("...and some more files"));
      vga.setColor(vga.COLOR_WHITE);
      break;
    }
    vga.print(i+1);
    vga.print(") ");
    vga.print(entry.name());
    //vga.write(entry.name());
    entry.close();
    i++;
  }
}

void loop()
{
  vga.setPos(75,29);
  report = vga.getReport();
  vga.setColor(vga.COLOR_CYAN_I);
  vga.setBackground(vga.COLOR_MAGENTA);
  vga.print(report.key1);
  vga.print(F("  "));
  tick++;
  delay(100);
}

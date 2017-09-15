/**
 * Example sketch to print list of files on SD card on the SPIVGA display
 */
#include <Arduino.h>
#include <SPIVGA.h>
#include <SPI.h>
#include <SD.h>

#define SPI_VGA_CS 10
#define SPI_SD_CS  9
#define SERIAL_SPEED 9600
#define DEBUG

SPIVGA vga(SPI_VGA_CS);
KeyboardReport report;
File root;
uint8_t tick = 0;

void setup()
{
#ifdef DEBUG  
    Serial.begin(SERIAL_SPEED);
    while (!Serial) {
      ; // wait for serial port to connect. Needed for native USB port only
    }
#endif

    SPI.begin();

#ifdef DEBUG
    Serial.print(F("Initializing VGA..."));  
#endif;

    vga.begin();
    vga.setColor(0xFF);
    vga.setBackground(0x00);
    vga.setPos(0,0);

#ifdef DEBUG
    Serial.print(F("Initializing SD Card..."));
#endif

    if (!SD.begin(8000000, SPI_SD_CS)) {
#ifdef DEBUG
      Serial.println(F("initialization failed!"));
#endif
      return;
    }

#ifdef DEBUG
    Serial.println(F("initialization done."));
#endif

    root = SD.open("/");
    printDirectory(root);
#ifdef DEBUG
    Serial.println(F("done!"));
#endif
}

void printDirectory(File dir) {
  int i = 0;
  while (true) {

    File entry =  dir.openNextFile();
    if (! entry) {
      // no more files
      break;
    }
#ifdef DEBUG
    Serial.println(entry.name());
#endif
    vga.setPos(10, i);
    vga.print(entry.name());
    entry.close();
    i++;
  }
}

void loop()
{
  vga.setPos(69,29);
  vga.setColor(0xFF);
  vga.setBackground(0x00);
  vga.write(tick);
  tick++;
  delay(1000);
}

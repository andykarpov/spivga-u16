#include <Arduino.h>
#include <SPIVGA.h>
#include <SPI.h>

SPIVGA vga(10); // cs pin = D10
KeyboardReport report;

void setup()
{
    SPI.begin();
    vga.begin();
    vga.setColor(0xFF);
    vga.setBackground(0x00);
    vga.setPos(0,0);
    vga.print(F("Hello world!"));
}

void loop()
{
    vga.noop();
    report = vga.getReport();
    if (report.key1 != 0xFF) {
        vga.setColor(B0101);
        vga.setPos(0,10);
        vga.print(F("Key pressed"));
    } else {
        vga.setColor(B1001);
        vga.setPos(0,10);
        vga.print(F("Key up     "));
    }
    delay(100);
}

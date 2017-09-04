#include <Arduino.h>
#include <SPIVGA.h>
#include <SPI.h>

SPIVGA vga(10); // cs pin = D10
KeyboardReport report;

void setup()
{
    SPI.begin();
    vga.begin();
    vga.setPos(0,0);
    vga.setColor(0xFF);
    vga.setBackground(0x00);
    vga.write("Hello world!");
}

void loop()
{
    vga.noop();
    report = vga.getReport();
    if (report.key1 != 0xFF) {
        vga.setPos(0,10);
        vga.write("Key pressed");
    } else {
        vga.setPos(0,10);
        vga.write("Key up     ");
    }
    delay(100);
}

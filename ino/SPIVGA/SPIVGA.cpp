/*
 Copyright (C) 2017 Andy Karpov <andy.karpov@gmail.com>

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 version 2 as published by the Free Software Foundation.
 */

// STL headers
// C headers
#include <avr/pgmspace.h>
// Framework headers
// Library headers
#include <SPI.h>
// Project headers
// This component's header
#include <SPIVGA.h>

#undef PROGMEM
#define PROGMEM __attribute__ ((section (".progmem.data"))) 
#undef PSTR 
#define PSTR(s) (__extension__({static char __c[] PROGMEM = (s); &__c[0];}))

/****************************************************************************/

// Commands

const uint8_t CMD_CLEAR = 0x1;
const uint8_t CMD_SET_POS = 0x2;
const uint8_t CMD_CHAR = 0x4;
const uint8_t CMD_NOOP = 0x8;

const uint8_t COLOR_BLANK = B0000;
const uint8_t COLOR_WHITE = B1111;

/****************************************************************************/

void SPIVGA::write_command(uint8_t _cmd, uint8_t _value1, uint8_t _value2)
{
  SPISettings settingsA(8000000, MSBFIRST, SPI_MODE1);
  KeyboardReport report;
  SPI.beginTransaction(settingsA);
  control_mode_on();
  delayMicroseconds(1); // tXCSS
  report.key0 = SPI.transfer(_cmd); // Write operation
  report.key1 = SPI.transfer(_value1); // Which register
  report.key2 = SPI.transfer(_value2); // Send hi byte
  delayMicroseconds(1); // tXCSH
  control_mode_off();
  SPI.endTransaction();
  setReport(report);
}

/****************************************************************************/

SPIVGA::SPIVGA( uint8_t _cs_pin):
  cs_pin(_cs_pin)
{
}

/****************************************************************************/

void SPIVGA::begin(void)
{
  pinMode(cs_pin,OUTPUT);
  digitalWrite(cs_pin,HIGH);
}

/****************************************************************************/

void SPIVGA::setPos(uint8_t x, uint8_t y)
{
  write_command(CMD_SET_POS, x, y);  
}

/****************************************************************************/

void SPIVGA::clear(void)
{
  write_command(CMD_CLEAR, 0, 0);  
}

/****************************************************************************/

size_t SPIVGA::write(uint8_t chr)
{
  uint8_t color = fg_color << 4;
  write_command(CMD_CHAR, chr, bg_color + color); 
  return 1; 
}

size_t SPIVGA::write(const char *str)
{
  size_t n = 0;
  uint8_t color = fg_color << 4;
  while (*str) {
    char c = *str;
    write_command(CMD_CHAR, (uint8_t)c, bg_color + color); 
    str++;
    n++;
  }
  return n;
}

void SPIVGA::setColor(uint8_t color)
{
    fg_color = color;
}

void SPIVGA::setBackground(uint8_t color)
{
    bg_color = color;
}

void SPIVGA::setReport(KeyboardReport _report)
{
   report = _report;
}

KeyboardReport SPIVGA::getReport(void)
{
  return report;
}

void SPIVGA::noop(void)
{
  write_command(CMD_NOOP, 0, 0); 
}

/****************************************************************************/

// vim:cin:ai:sts=2 sw=2 ft=cpp

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
#include <Arduino.h>

/****************************************************************************/

// Commands

const uint8_t CMD_CLEAR = 0x1;
const uint8_t CMD_SET_POS = 0x2;
const uint8_t CMD_CHAR = 0x4;
const uint8_t CMD_NOOP = 0x8;

/****************************************************************************/

void SPIVGA::write_command(uint8_t _cmd, uint8_t _value1, uint8_t _value2)
{
  SPISettings settingsA(40000000, MSBFIRST, SPI_MODE0);
  KeyboardReport report;
  SPI.beginTransaction(settingsA);
  control_mode_on();
  report.key0 = SPI.transfer(_cmd);
  report.key1 = SPI.transfer(_value1);
  report.key2 = SPI.transfer(_value2);
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
  current_x = x;
  current_y = y;

  if (x >= 80) {
    current_x = 0;
    current_y++;
  }

  if (y >= 30) {
    current_y = 0;
    current_x = 0;
  }
  write_command(CMD_SET_POS, current_y, current_x);
}

/****************************************************************************/

void SPIVGA::clear(void)
{
  fill(0);
  //write_command(CMD_CLEAR, 0, 0);
}

void SPIVGA::fill(uint8_t chr)
{
  setPos(0,0);
  for (uint8_t y=0; y<30; y++) {
    for (uint8_t x=0; x<80; x++) {
      write(chr);
    }
  }
}

void SPIVGA::fill(uint8_t x1, uint8_t y1, uint8_t x2, uint8_t y2, uint8_t chr)
{
    setPos(x1, y1);
    for (uint8_t y=y1; y<=y2; y++) {
        setPos(x1, y);
        for (uint8_t x=x1; x<=x2; x++) {
            write(chr);
        }
    }
}

void SPIVGA::frame(uint8_t x1, uint8_t y1, uint8_t x2, uint8_t y2, uint8_t thickness)
{
    setPos(x1,y1);
    for(uint8_t y=y1; y<=y2; y++) {
        setPos(x1, y);
        for(uint8_t x=x1; x<=x2; x++) {
	    if (y==y1 && x==x1) {
                write(201); // lt
            }
            else if (y==y2 && x==x1) {
                write(200); // lb
            }
            else if (y==y1 && x==x2) {
                write(187); // rt
            }
            else if (y==y2 && x==x2) {
                write(188); // rb
            }
            else if (y==y1 || y == y2) {
                write(205); // t / b
            }
            else if ((x==x1 && y>y1 && y<y2) || (x==x2 && y>y1 && y<y2)) {
                setPos(x,y);
                write(186); // l / r
            }
        }
    }
}

/****************************************************************************/

size_t SPIVGA::write(uint8_t chr)
{
  uint8_t color = fg_color << 4;
  write_command(CMD_CHAR, chr, bg_color + color);
  setPos(current_x+1, current_y);
  return 1; 
}

/****************************************************************************/

void SPIVGA::setColor(uint8_t color)
{
    fg_color = color;
}

/****************************************************************************/

void SPIVGA::setBackground(uint8_t color)
{
    bg_color = color;
}

/****************************************************************************/

void SPIVGA::setReport(KeyboardReport _report)
{
   report = _report;
}

/****************************************************************************/

KeyboardReport SPIVGA::getReport(void)
{
  return report;
}

/****************************************************************************/

void SPIVGA::noop(void)
{
  write_command(CMD_NOOP, 0, 0); 
}

/****************************************************************************/

// vim:cin:ai:sts=2 sw=2 ft=cpp

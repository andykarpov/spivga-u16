/*
 Copyright (C) 2017 Andy Karpov <andy.karpov@gmail.com>

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 version 2 as published by the Free Software Foundation.
 */

#ifndef __SPIVGA_H__
#define __SPIVGA_H__

// STL headers
// C headers
// Framework headers
#if ARDUINO < 100
#include <WProgram.h>
#else
#include <Arduino.h>
#endif

// Library headers
// Project headers
#include "keyboard_report.h"
#include <avr/pgmspace.h>

/****************************************************************************/


/**
 * Driver library for SPIVGA project: a simple ASCII VGA adapter on FPGA
 */

class SPIVGA : public Print
{
private:
  uint8_t cs_pin;
  uint8_t fg_color;
  uint8_t bg_color;
  KeyboardReport report;

protected:

  inline void control_mode_on(void) const
  {
    digitalWrite(cs_pin,LOW);
  }

  inline void control_mode_off(void) const
  {
    digitalWrite(cs_pin,HIGH);
  }

  void setReport(KeyboardReport _report);

  void write_command(uint8_t _cmd, uint8_t _value1, uint8_t _value2);

public:
  /**
   * Constructor
   *
   * Only sets pin values.  Be sure to call begin()!
   */
  SPIVGA( uint8_t _cs_pin);

  /**
   * Begin operation
   *
   * Sets pins correctly, and prepares SPI bus.
   */
  void begin(void);

  /**
   * Set character position
   *
   * @param x position x (0...79)
   * @param y position y (0...29)
   */
  void setPos(const uint8_t x, const uint8_t y);

  /**
   * Set fg color
   *
   * @param color
   */
  void setColor(uint8_t color);

  /**
   * Set bg color
   *
   * @param color
   */
  void setBackground(uint8_t color);

  /**
   * Clear screen
   *
   * Set black bg to the whole screen
   */
  void clear(void);

  /**
   * Empty command, just to update keyboard report
   *
   */
  void noop(void);

  /**
   * Get last keyboard report
   * 
   */
  KeyboardReport getReport(void);

  /**
   * Write a single characted
   *
   * @param chr character byte.
   */
  virtual size_t write(uint8_t chr);

  /**
   * Write a string
   *
   * @param *str string.
   */
  virtual size_t write(const char *str);

  /**
   * Write a buffer of the given size
   *
   * @param *buffer
   * @param size
   */
  virtual size_t write(const uint8_t *buffer, size_t size);

};

#endif // __SPIVGA_H__
// vim:cin:ai:sts=2 sw=2 ft=cpp

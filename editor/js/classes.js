'use strict';

function dec2hex(i)
{
  var result = "0000";
  if      (i >= 0    && i <= 15)    { result = "000" + i.toString(16); }
  else if (i >= 16   && i <= 255)   { result = "00"  + i.toString(16); }
  else if (i >= 256  && i <= 4095)  { result = "0"   + i.toString(16); }
  else if (i >= 4096 && i <= 65535) { result =         i.toString(16); }
  return result.toUpperCase();
}

class FontGlyph {

    constructor(width, height, data) {
        this.width = width;
        this.height = height;
        this.data = data;
    }

    getPixel(x, y) {
        return (this.data[y] >> this.width-x) & 1;
    }
};

class Font {

    constructor(width, char_width, char_height, data) {
        this.width = width;
        this.char_width = char_width;
        this.char_height = char_height;
        this.glyphs = [];
        for (var i=0; i<width; i++) {
            var glyph = new FontGlyph(char_width, char_height, data[i]);
            this.glyphs[i] = glyph;
        }
    }

    getGlyph(pos) {
        return this.glyphs[pos];
    }
};

class Symbol {

    constructor() {
        this.value = 0;
        this.color = 0;
        this.bgcolor = 0;
    }

    setValue(value) {
        this.value = value;
    }

    setColor(color) {
        this.color = color;
    }

    setBackground(color) {
        this.bgcolor = color;
    }

    getValue() {
        return this.value;
    }

    getColor() {
        return this.color;
    }

    getBackground() {
        return this.bgcolor;
    }
};

class VideoMemory {

    constructor(width, height) {

        this.width = width;
        this.height = height;
        this.mem = [];

        for (var i=0; i<this.width; i++) {
            for (var j=0; j<this.height; j++) {
                var symbol = new Symbol();
                symbol.setValue(0);
                symbol.setColor(0);
                symbol.setBackground(0);
                if (this.mem[j] == undefined) {
                    this.mem[j] = [];
                }
                this.mem[j][i] = symbol;
            }
        }
    }

    setDataAtPos(x, y, value, color, background) {
        this.mem[y][x].setValue(value);
        this.mem[y][x].setColor(color);
        this.mem[y][x].setBackground(background);
    }

    getDataAtPos(x, y) {
        return this.mem[y][x];
    }
};

class Renderer {

    constructor(width, height) {
        this.width = width;
        this.height = height;
    }

    setFont(font) {
        this.font = font;
        this.current_symbol = new Symbol();
        this.current_symbol.setColor(127);
    }

    setMemory(memory) {
        this.memory = memory;
    }

    setCurrentSymbol(symbol) {
        this.current_symbol = symbol;
    }

    getCurrentSymbol() {
        return this.current_symbol;
    }

    setFontChar(value) {
        this.current_symbol.setValue(value);
    }

    setFontColor(color) {
        this.current_symbol.setColor(color);
    }

    setFontBackground(color) {
        this.current_symbol.setBackground(color);
    }

    setCanvas(canvas) {
        this.canvas = canvas;
        this.ctx = this.canvas.getContext("2d");
        this.mouse = {over: false, down: false, x: 0, y: 0, last_x: 0, last_y: 0};
        this.canvas.addEventListener('mousemove', this.mouseMove.bind(this));
        this.canvas.addEventListener('mouseleave', this.mouseLeave.bind(this));
        this.canvas.addEventListener('mousedown', this.mouseClick.bind(this));
        this.canvas.addEventListener('mouseup', this.mouseUnclick.bind(this));
    }

    redrawChar(xx, yy) {
        for (var y=yy; y<yy+this.font.char_height; y++) {
            for (var x=xx; x<xx+this.font.char_width; x++) {
                var char_x = Math.floor(x/this.font.char_width);
                var char_y = Math.floor(y/this.font.char_height);
                var symbol = this.memory.getDataAtPos(char_x, char_y);
                var value = symbol ? symbol.getValue() : 0;
                var color = symbol ? symbol.getColor() : 0;
                var bg    = symbol ? symbol.getBackground() : 0;
                var glyph = this.font.getGlyph(value);
                var glyph_x = Math.floor(x % this.font.char_width);
                var glyph_y = Math.floor(y % this.font.char_height);
                var pixel = glyph.getPixel(glyph_x, glyph_y);
                this.ctx.fillStyle = this.getFillStyle(pixel, color, bg);
                this.ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    mouseMove(params) {
        this.mouse.over = true;        
        var rect = this.canvas.getBoundingClientRect();
        var xx = Math.floor((params.clientX - rect.left) / this.font.char_width) * this.font.char_width;
        var yy = Math.floor((params.clientY - rect.top) / this.font.char_height) * this.font.char_height;

        if (xx != this.mouse.x || yy != this.mouse.y) {
            this.mouse.x = xx;
            this.mouse.y = yy;
            if (this.mouse.click) {
                this.memory.setDataAtPos(
                    Math.floor(this.mouse.x/this.font.char_width),
                    Math.floor(this.mouse.y/this.font.char_height),
                    this.current_symbol.getValue(),
                    this.current_symbol.getColor(),
                    this.current_symbol.getBackground()
                );
            } else {
                this.ctx.fillStyle="rgba("+0+","+255+","+0+","+(127/255)+")";  ;
                this.ctx.fillRect(this.mouse.x, this.mouse.y, this.font.char_width, this.font.char_height);
            }
        }

        if (this.mouse.x != this.mouse.last_x || this.mouse.y != this.mouse.last_y) {
            this.redrawChar(this.mouse.last_x, this.mouse.last_y);
            this.mouse.last_x = this.mouse.x;
            this.mouse.last_y = this.mouse.y;
        }
    }

    mouseLeave() {
        this.mouse.over = false;
        this.mouse.click = false;
        this.redrawChar(this.mouse.x, this.mouse.y);
    }

    mouseClick(params) {
        this.mouse.click = true;
        this.memory.setDataAtPos(
            Math.floor(this.mouse.x/this.font.char_width),
            Math.floor(this.mouse.y/this.font.char_height),
            this.current_symbol.getValue(),
            this.current_symbol.getColor(),
            this.current_symbol.getBackground()
        );
    }

    mouseUnclick(params) {
        this.mouse.click = false;
    }

    getFillStyle(pixel, color, bgcolor) {

        if (pixel) {
            return (ColorMap[color]) ? ColorMap[color] : "#000000";
        } else {
            return (ColorMap[bgcolor]) ? ColorMap[bgcolor] : "#000000";
        }
    }

    render() {
        this.ctx.clearRect(0, 0, this.width, this.height);
        for (var y=0; y<this.height; y++) {
            for (var x=0; x<this.width; x++) {                
                var char_x = Math.floor(x/this.font.char_width);
                var char_y = Math.floor(y/this.font.char_height);
                var symbol = this.memory.getDataAtPos(char_x, char_y);
                var value = symbol ? symbol.getValue() : 0;
                var color = symbol ? symbol.getColor() : 0;
                var bg    = symbol ? symbol.getBackground() : 0;
                var glyph = this.font.getGlyph(value);
                var glyph_x = Math.floor(x % this.font.char_width);
                var glyph_y = Math.floor(y % this.font.char_height);
                var pixel = glyph.getPixel(glyph_x, glyph_y);
                this.ctx.fillStyle = this.getFillStyle(pixel, color, bg);
                this.ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    getMemoryDump() {
        var result = "bin2mif project\n";
        result += "WIDTH = 16;\n";
        result += "DEPTH = 4096;\n";
        result += "\n";
        result += "ADDRESS_RADIX = HEX;\n";
        result += "DATA_RADIX = HEX;\n";
        result += "CONTENT BEGIN\n";
        for (var y=0; y<Math.floor(this.height/this.font.char_height); y++) {
            for (var x=0; x<Math.floor(this.width/this.font.char_width); x++) {
                var item = this.memory.getDataAtPos(x,y);
                var addr = dec2hex(x + y*128);
                var data = dec2hex(item.getValue()*256 + item.getColor()*16 + item.getBackground());
                if (data != "0000") {
                    result = result + addr + " : " + data + ";\n";                    
                }
            }
        }
        result += "END\n";
        return result;
    }
};

class FontChooser {

    constructor(width, height) {
        this.width = width;
        this.height = height;
        this.mouse = {x: 0, y: 0};
    }

    setFont(font) {
        this.font = font;
    }

    setCanvas(canvas) {
        this.canvas = canvas;
        this.ctx = this.canvas.getContext("2d");        
        this.canvas.addEventListener('mousedown', this.mouseClick.bind(this));
    }

    mouseClick(params) {
        var rect = this.canvas.getBoundingClientRect();
        var xx = Math.floor((params.clientX - rect.left) / this.font.char_width) * this.font.char_width;
        var yy = Math.floor((params.clientY - rect.top) / this.font.char_height) * this.font.char_height;
        if (xx != this.mouse.x || yy != this.mouse.y) {
            this.ctx.fillStyle="rgba("+0+","+255+","+0+","+(127/255)+")";  ;
            this.ctx.fillRect(xx, yy, this.font.char_width, this.font.char_height);
            this.redrawChar(this.mouse.x, this.mouse.y);
            this.mouse.x = xx;
            this.mouse.y = yy;
            this.choose_callback(
                (yy/this.font.char_height)*(this.width/this.font.char_width) + (xx/this.font.char_width)
            );
        }
    }

    onChoose(callback) {
        this.choose_callback = callback;
    }

    redrawChar(xx, yy) {
        for (var y=yy; y<yy+this.font.char_height; y++) {
            for (var x=xx; x<xx+this.font.char_width; x++) {
                var char_x = Math.floor(x/this.font.char_width);
                var char_y = Math.floor(y/this.font.char_height);
                var value = (yy/this.font.char_height)*(this.width/this.font.char_width) + (xx/this.font.char_width);
                var glyph = this.font.getGlyph(value);
                if (!glyph) glyph = this.font.getGlyph(0);
                var glyph_x = Math.floor(x % this.font.char_width);
                var glyph_y = Math.floor(y % this.font.char_height);
                var pixel = glyph.getPixel(glyph_x, glyph_y);
                this.ctx.fillStyle = (pixel) ? "#FFFFFF" : "000000";
                this.ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    render() {
        this.ctx.clearRect(0, 0, this.width, this.height);
        for (var y=0; y<this.height / this.font.char_height; y++) {
            for (var x=0; x<this.width / this.font.char_width; x++) {
                this.redrawChar(x*this.font.char_width, y*this.font.char_height);
            }
        }
    }
};

var ColorMap = {
    0 :  "#000000",
    1 :  "#000000",
    2 :  "#00007F",
    3 :  "#0000FF",
    4 :  "#007F00",
    5 :  "#00FF00",
    6 :  "#007F7F",
    7 :  "#00FFFF",
    8 :  "#7F0000",
    9 :  "#FF0000",
    10 : "#7F007F",
    11 : "#FF00FF",
    12 : "#7F7F00",
    13 : "#FFFF00",
    14 : "#7F7F7F",
    15 : "#FFFFFF"
};

class ColorChooser {

    constructor(width, height) {
        this.width = width;
        this.height = height;
        this.mouse = {x: 0, y: 0};
        this.map = ColorMap;
    }

    setCanvas(canvas) {
        this.canvas = canvas;
        this.ctx = this.canvas.getContext("2d");        
        this.canvas.addEventListener('mousedown', this.mouseClick.bind(this));
    }

    mouseClick(params) {
        var rect = this.canvas.getBoundingClientRect();
        var xx = Math.floor((params.clientX - rect.left) / 16) * 16;
        var yy = Math.floor((params.clientY - rect.top) / 16) * 16;
        if (xx != this.mouse.x || yy != this.mouse.y) {
            this.ctx.strokeStyle="rgba("+0+","+0+","+0+","+(255/255)+")";
            this.ctx.strokeRect(xx, yy, 16, 16);
            this.redrawChar(this.mouse.x, this.mouse.y);
            this.mouse.x = xx;
            this.mouse.y = yy; 
            var color = Math.floor((yy/16)*(this.width/16) + (xx/16));           
            this.choose_callback(color);
        }
    }

    onChoose(callback) {
        this.choose_callback = callback;
    }

    redrawChar(xx, yy) {
        var value = (yy/16)*(this.width/16) + (xx/16);
        var color = (this.map[value]) ? this.map[value] : "#000000";
        this.ctx.fillStyle = color;
        this.ctx.fillRect(xx, yy, 16, 16);
    }

    render() {
        this.ctx.clearRect(0, 0, this.width, this.height);
        for (var y=0; y<this.height / 16; y++) {
            for (var x=0; x<this.width / 16; x++) {
                this.redrawChar(x*16, y*16);
            }
        }
    }
};

class App {
    constructor() {

        this.font = new Font(255, 8, 16, font_data);
        this.mem = new VideoMemory(80, 30);

        this.font_chooser = new FontChooser(512, 64);
        this.font_chooser.setFont(this.font);
        this.font_chooser.setCanvas(document.getElementById('font_chooser'));
        this.font_chooser.onChoose(function(value){
            this.renderer.setFontChar(value);
        }.bind(this));


        this.color_chooser = new ColorChooser(128, 32);
        this.color_chooser.setCanvas(document.getElementById('color_chooser'));
        this.color_chooser.onChoose(function(color){
            this.renderer.setFontColor(color);
        }.bind(this));

        this.bgcolor_chooser = new ColorChooser(128, 32);
        this.bgcolor_chooser.setCanvas(document.getElementById('bgcolor_chooser'));
        this.bgcolor_chooser.onChoose(function(color){
            this.renderer.setFontBackground(color);
        }.bind(this));

        this.renderer = new Renderer(640, 480);
        this.renderer.setFont(this.font);
        this.renderer.setMemory(this.mem);
        this.renderer.setCanvas(document.getElementById('canvas'));

        document.getElementById('btn-get-output').addEventListener('click', function(){
            var dump = this.renderer.getMemoryDump();
            document.getElementById('output').value = dump;
        }.bind(this));
    }

    run() {
        this.font_chooser.render();
        this.renderer.render();
        this.color_chooser.render();
        this.bgcolor_chooser.render();
    }
};

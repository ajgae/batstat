# `batstat` 

Simple script that displays battery percentage and {dis,}charge rate.

## Usage

Command-line options:

- `-n`: Do not append a newline to the output (which is the default
  behavior)
- `-b`: Print battery percentage only (incompatible with -w)
- `-w`: Print wattage only (incompatible with -b)
- `-f FORMAT`: Use the specified output format for colors. FORMAT must
  be one of 'ansi' or 'xml' (default: 'ansi'). 'xfce-genmon' is
  intended for use with the Xfce4 panel general monitor plugin (see
  https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin/)


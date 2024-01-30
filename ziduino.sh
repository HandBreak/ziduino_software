#!/bin/bash
z80asm -i ./ziduino_main.asm -o ./bios_z80.bin
echo 'Z80 Compilation complete!'
echo 'Start firmware uploading from #0000'
sudo ./bios_loader ./bios_z80.bin 0
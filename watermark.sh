#!/bin/bash
cp flash_rom.mif save_flash_rom.mif
cat flash_rom.mif | head -n 1957 > temp_seg1
git rev-parse HEAD | head -c7 | basenc --base2msbf --wrap=8 | awk -f format_commit.awk > temp_seg2
cat flash_rom.mif | tail -n +1961 > temp_seg3
cat temp_seg1 temp_seg2 temp_seg3 > flash_rom.mif


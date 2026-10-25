#!/bin/bash
set -euo pipefail
export PATH=/audit/tools:/audit/venv/bin:$PATH PYTHONPATH=/audit/python-evic EVICSDK=/audit/sdk ARMGCC=/usr/lib SOURCE_DATE_EPOCH=1792902672
cd /audit/build-default
for run in 3 4; do
 make clean > /audit/logs/ron7-clean-$run.log 2>&1
 make -f Makefile -f /audit/map.mk -j2 all > /audit/logs/ron7-build-$run.log 2>&1
 mkdir -p /audit/private-artifacts/run$run
 cp bin/myevic* /audit/private-artifacts/run$run/
 sha256sum bin/myevic* > /audit/logs/ron7-hashes-$run.txt
done
cmp /audit/private-artifacts/run3/myevic.bin /audit/private-artifacts/run4/myevic.bin
cmp /audit/private-artifacts/run3/myevic_dec.bin /audit/private-artifacts/run4/myevic_dec.bin
cmp /audit/private-artifacts/run3/myevic.elf /audit/private-artifacts/run4/myevic.elf
arm-none-eabi-readelf -lW bin/myevic.elf > /audit/logs/ron7-readelf-l.txt
arm-none-eabi-readelf -SW bin/myevic.elf > /audit/logs/ron7-readelf-S.txt
arm-none-eabi-objdump -h bin/myevic.elf > /audit/logs/ron7-objdump-h.txt
arm-none-eabi-nm -n bin/myevic.elf > /audit/logs/ron7-nm.txt
arm-none-eabi-size -A bin/myevic.elf > /audit/logs/ron7-size.txt
make -np 2>/dev/null | sed -n 's/^\.DEFAULT_GOAL := /DEFAULT_GOAL=/p' > /audit/logs/default-goal.txt


loadbit:
	./fpgaprog -v -f ../ISE/plustoo_top.bit

flashbit:
	./fpgaprog.exe -v -f ../ISE/plustoo_top.bit -b bscan_spi_lx25_ftg256.bit -sa -r

plustoorom: plustoorom.bit
	./fpgaprog.exe -v -f plustoorom.bit -b bscan_spi_lx25_ftg256.bit -sa -r

plustoo605: plustoo605.bit
	./fpgaprog.exe -v -f plustoo605.bit -b bscan_spi_lx25_ftg256.bit -sa -r

cm93: cm93.bit
	./fpgaprog.exe -v -f cm93.bit -b bscan_spi_lx25_ftg256.bit -sa -r

plustoo605.bit: plustoorom.bit Disk605.dsk
	./bitmerge plustoorom.bit 180000:Disk605.dsk plustoo605.bit

cm93.bit: plustoo605.bit CM93.dsk
	./bitmerge plustoo605.bit 280000:CM93.dsk cm93.bit

plustoorom.bit: ../ISE/plustoo_top.bit plusrom.bin
	./bitmerge ../ISE/plustoo_top.bit 160000:plusrom.bin plustoorom.bit
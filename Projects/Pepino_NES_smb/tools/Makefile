

loadbit: nes_top_smb_mb.bit
	./fpgaprog -v -f nes_top_smb_mb.bit

flashbit: nes_top_smb_mb.bit
	./fpgaprog -v -f nes_top_smb_mb.bit -b bscan_spi_lx25_ftg256.bit -sa -r

nes_top_smb_mb.bit: nes_top_mb.bit chrrom.bmm prgrom.bmm chrrom_scrambled.mem prgrom_scrambled.mem
	./data2mem -bm chrrom.bmm -bd chrrom_scrambled.mem -bt nes_top_mb.bit -o b temp.bit
	./data2mem -bm prgrom.bmm -bd prgrom_scrambled.mem -bt temp.bit -o b nes_top_smb_mb.bit
	rm -f temp.bit

nes_top_mb.bit: ../hw/ise/nes_top.bit ../hw/ise/ipcore_dir/microblaze_mcs_v1_3_bd.bmm nes_smb.elf
	./data2mem -bm ../hw/ise/ipcore_dir/microblaze_mcs_v1_3_bd.bmm -bd nes_smb.elf -bt ../hw/ise/nes_top.bit -o b nes_top_mb.bit


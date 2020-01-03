ASM = nasm
QEMU = qemu-system-i386
TOOLCHAIN_DIR = toolchain-dir/usr/local/i686-elf-gcc/bin/
CPP = $(TOOLCHAIN_DIR)/i686-elf-g++
LD = $(TOOLCHAIN_DIR)/i686-elf-ld

CPP_FLAGS = -ffreestanding

OS_SIZE_IN_SECTORS = 17  # kernel size + 1 (for the boot sector)

OBJS = kernel.o

all: myos.iso

clean:
	rm -rf *.bin *.o *.iso

run: myos.iso
	$(QEMU) $< -curses

boot.bin: boot.asm
	$(ASM) -f bin -o $@ $<

kernel_entry.o: kernel_entry.asm
	$(ASM) -f elf -o $@ $<

%.o: %.cpp
	$(CPP) -c $(CPP_FLAGS) -o $@ $<

kernel.bin: kernel_entry.o $(OBJS)
	$(LD) -o $@ -Ttext 0x1000 $^ --oformat binary

myos.iso: boot.bin kernel.bin
	cat $^ /dev/zero | dd of=$@ bs=512 count=$(OS_SIZE_IN_SECTORS)

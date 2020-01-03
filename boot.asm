; This file is meant to be a standalone boot process that passes control to
; 32-bit protected mode. This includes:
; - Loading the GDT and IDT
; - Loading the kernel
; - Transferring control to the kernel through kmain()
;
; This file is also extensively commented for learning purposes. If anything
; is wrong or some crucial step is missing, update this file accordingly.

; The default size for operations like `push` will be 16 bits since we start in
; 16-bit real mode.
[bits 16]

; On x86, the BIOS will place our bootloader here.
[org 0x7c00]

; 0x9000 should sufficiently be far enough from our boot sector.
; See https://wiki.osdev.org/Memory_Map_(x86) for free areas we can use while
; 16-bit mode. Remember the stack will grow downwards.
%define STACK_START_16B 0x9000

; TODO: We will need to update the stack to a new location since we can have a
; lot more data on the stack eventually. We could store this into upper memory
; now that we have access to it, but we should get a memory layout first to get
; a reliable map of upper memory (https://wiki.osdev.org/Memory_Map_(x86)). For
; now, since we don't know, we can still place it in a reliable area in lower
; memory.
%define STACK_START_32B 0x70000

; Our kernel will be loaded here. It's important we have enough space so we
; don't overwrite the boot sector loaded at 0x7c00.
%define KERNEL_ENTRY 0x1000
%define NUM_SECTORS_TO_READ 16  ; Size will be 512 x this

  jmp entry

%include "print.asm"
%include "gdt.asm"

entry:
  ; Set DS to zero since it may not already be zero. If it's not zero, then we
  ; could be loading from incorrect addresses.
  xor ax, ax
  mov ds, ax
  mov es, ax  ; We will use this later to load the kernel
  mov [boot_drive], dl  ; Save the drive # we were loaded in

  ; Setup the stack in case we use it.
  mov bp, STACK_START_16B  ; Stack base
  mov sp, bp           ; Stack top (this will decrement)

  mov edx, msg_real_mode
  call println_16b

  ; Load the kernel.
  mov edx, msg_loading_kernel
  call println_16b

  ; See https://en.wikipedia.org/wiki/INT_13H for info on reading sectors
  ; from drive.
  mov ah, 2
  mov al, NUM_SECTORS_TO_READ

  ; Load the kernel at this address [es:bx]
  mov bx, KERNEL_ENTRY

  ; Start reading at the 2nd sector. We loading this boot program on the 1st
  ; sector. This argument specifically is indexed from 1, not 0.
  mov cx, 2
  mov dh, 0  ; Head #
  mov dl, [boot_drive]  ; Drive #
  int 0x13
  jc disk_error  ; Carry bit is set on error

  cmp al, NUM_SECTORS_TO_READ
  jne sectors_error

  mov edx, msg_loaded_kernel
  call println_16b

  ; We have now loaded the kernel. Now switch to 32-bit protected mode.
  ; Disable interupts because once we make the switch to 32-bit mode, interupt
  ; handling will operate completely differentely than in 16-bit mode.
  cli
  lgdt [gdt_descriptor]
  mov eax, cr0
  or eax, 1  ; We are in 32-bit mode once we set this bit
  mov cr0, eax

  ; Jump to 32 bit code and force the CPU to flush its cache of pre-fetched and
  ; real-mode decoded instructions, which can cause problems.
  jmp CODE_SEG:entry_protected_mode

[bits 32]
entry_protected_mode:
  ; Update the segment registers since our old segments are meaningless.
  mov ax, DATA_SEG
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov fs, ax
  mov gs, ax

  ; Set the new stack location since we have access to more memory now.
  mov ebp, STACK_START_32B
  mov esp, ebp

  ; Enter our kernel.
  call KERNEL_ENTRY
  jmp $  ; Hang if we somehow get back to this point.

[bits 16]
disk_error:
  push dx
  mov edx, msg_disk_error
  call println_16b
  pop dx
  mov dh, ah ; ah = error code, dl = disk drive that dropped the error
             ; Lookup error codes at http://stanislavs.org/helppc/int_13-1.html
  call print_hex
  jmp $

sectors_error:
  mov edx, msg_sectors_error
  call println_16b
  mov dx, 0
  mov dl, al
  call print_hex
  jmp $

msg_real_mode:
  db "Started in 16-bit real mode.", 0
msg_loading_kernel:
  db "Loading the kernel...", 0
msg_loaded_kernel:
  db "Loaded the kernel!", 0
msg_disk_error:
  db "Disk read error (High: error code, Low: drive that dropped the error)", 0
msg_sectors_error:
  db "Incorrect number of sectors read", 0
msg_entered_pm:
  db "Entered 32-bit protected mode.", 0

boot_drive: db 0

; The boot sector must always end with the boot signiature (0xaa55) and must
; always be 512 bytes long.
  times 510-($-$$) db 0
  db 0x55
  db 0xaa

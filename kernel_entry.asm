; This file exists solely to be linked with the rest of the kernel and jump to
; kmain(), since kmain() can be loacted anywhere in the kernel. What matters is
; that we jump to this point first from the boot loader.
[bits 32]
[extern kmain]
call kmain
jmp $  ; Hang if we somehow get back to this point.

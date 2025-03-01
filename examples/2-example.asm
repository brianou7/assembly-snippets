// Example No. 2
.global _start
.equ N, 3
.text
_start:

mov r0,#N
ldr r1,=A

loop:

ldr r2, [r1, #0]
ldr r3, [r1, #(1*N*4)]

mul r4, r2, r3
ldr r5, [r1, #(3*N*4)]
add r4, r4, r5

str r4, [r1, #(2*N*4)]
add r1, r1, #4
subs r0, r0, #1

bne loop

stop:

b stop

.data
A: .dc.l 0x1, 0x2, 0x3 // Vector A
B: .dc.l 0x3, 0x5, 0x4 // Vector B
R: .ds.l N // Vector R
C: .dc.l 0x5, 0x6, 0x2 // Vector C
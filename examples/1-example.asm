// Example #1
.text // Code section
.global _start
_start:

MOV r0, #9 // Store decimal 9 in register r0
MOV r1, #0xE // Store hex E (decimal 14) in register r1
ADD r2, r1, r0 // Add into r2 the contents of r0 and r1

// End program
_stop:

B _stop
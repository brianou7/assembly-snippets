// https://developer.arm.com/documentations
.global _start
.equ N, 4
.text
_start:
    push {r4-r11}         
    mov r4, #N            
    ldr r5, =A            // dirección del primer valor de A
    ldr r6, =B            // dirección del primer valor de B
    ldr r7, =R            // dirección de almacenaje valor R
    mov r8, #0            // Initializar contador

    // NOTE: Extraer los datos de los registros con  A AND Mask
    // NOTE: Desplazamientos para obtener valores 

    // Precarga de valores por defecto si es infinito
    ldr r9, =INFINITY     // Constante infinito 0x7F800000 
    ldr r10, =NAN         // Constante Nan 0x7FC00000 
loop:
    cmp r8, r4            // Comparar contador con N
    bge finish            // Break de salida sin ya se supero N

    ldr r0, [r5, r8, LSL #2]   // Cargar A[i]: dodne i es el puntero donde va
    ldr r1, [r6, r8, LSL #2]   // Cargar B[i]: es el mismo puntero porque es 1 a 1

    bl multiply_float     // llamar a la función multiplicacion

    str r0, [r7, r8, LSL #2]   // Almacenar resultados en R[i]

    add r8, r8, #1        // Increment contador en 1
    b loop                // Continuar loop
multiply_float:
    push {lr}             // guardar y devolver dirección
    // Verificación casos especiales

    // verificacion operaciones con cero
    cmp r0, #0
    beq zero_check        // si en el registro hay cero se va a la validacion de cero
    // Verificación de infinito o NaN
    ldr r2, [r9]          // cargar infinito
    and r3, r0, r2        // Extraer exponente de primer operando
    and r2, r1, r2        // Extraer exponente de segundo operando
    cmp r3, r2            // Comparar exponentes
    beq special_check     // Se va al manejo de esos casos especiales
    // Multiplicación normal usando registros y pila
    push {r0, r1}         // Guardar A y B en la pila
    mov r2, r0            // Copiar A a r2
    mov r3, r1            // Copiar B a r3
    mul r0, r2, r3        // Multiplicar A y B
    pop {r0, r1}          // Restaurar A y B desde la pila
    b multiply_end
zero_check:
    // 0 × ±finito = 0
    cmp r1, #0
    bne multiply_end      // Si r1 no es cero, devuelve 0
    // 0 × ±infinito = NaN
    ldr r2, [r9]          // Cargar infinit0
    and r2, r1, r2
    cmp r2, r2
    ldreq r0, [r10]       // Cargar NaN si r1 es infinito
    b multiply_end
special_check:
    // ±finito × ±infinito = ±infinito
    ldr r2, [r9]          // Cargar infinito
    cmp r3, r2
    ldreq r0, [r9]        // Infinito +
    beq multiply_end
    //Casos NaN
    cmp r3, r2
    ldreq r0, [r10]       // NaN si el primer operando es NaN
    beq multiply_end
    cmp r2, r2
    ldreq r0, [r10]       // NaN si el segundo operando es NaN
    beq multiply_end
    // Multiplicacion sin caso especial
    vmov s0, r0
    vmov s1, r1
    vmul.f32 s2, s0, s1
    vmov r0, s2

// TODO: Special case for - infinity

multiply_end:
    pop {lr}
    bx lr
finish:
    pop {r4-r11}          
    b finish              // loop infinito para bloquear ejecución
.data
R:  .ds.l N               // Reserve space for results
A:  .dc.l 0xC1900000, 0x80800000, 0x1E2548FE, 0x23457242   // Valores A: [-18.0, -1.1754944E-38, 8.750122E-21, 1.07035864E-17]
B:  .dc.l 0x41180000, 0x3F800000, 0x211145A2, 0x12453010   // Valores B: [9.5, 1.0, 4.922007E-19, 6.222148E-28]
INFINITY: .word 0x7F800000   // Infinito
NAN:      .word 0x7FC00000   // NaN 
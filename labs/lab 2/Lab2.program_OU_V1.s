/* Programa: Multiplicación de N números de punto flotante (IEEE-754, 32-bit) */
.global _start           @ Punto de entrada del programa
.equ N, 4               @ Número de operaciones a realizar (N = 4)

.macro dsl val          @ Macro para reservar 'val' longwords (32-bit) en .data
    .space (4 * \val)
.endm

.macro dcl list         @ Macro para definir constantes longwords (32-bit) en .data
    .word \list
.endm

.text
_start:
    mov    r6, #N          @ Cargar el número de operación a realizar
    ldr    r4, =A          @ Cargar dirección donde se encuentra el primer valor de A
    ldr    r5, =B          @ Cargar dirección donde se encuentra el primer valor de B
    ldr    r7, =R          @ Cargar dirección donde se almacenará el primer resultado R

/* LOOP N */
loop:
    /* Leer A[i] y B[i] */
    ldr    r0, [r4], #4    @ Cargar A[i] en r0 y avanzar puntero A
    ldr    r1, [r5], #4    @ Cargar B[i] en r1 y avanzar puntero B
    /* Algoritmo para realizar R[i] = A[i] * B[i] 
       El programa deberá tener al menos dos funciones que serán llamadas durante la ejecución.
       Dichas funciones deberán emplear el Stack para mantener el valor de los registros 
       que se deberán preservar de acuerdo con la convención de regs. */
    bl     float_multiply  @ Llamar a función de multiplicación en punto flotante
    /* Almacenar R[i] */
    str    r0, [r7], #4    @ Almacenar resultado en R[i] y avanzar puntero R
    subs   r6, r6, #1      @ Decrementar contador de operaciones
    bne    loop            @ Repetir mientras queden operaciones por realizar

finish:
    b      finish          @ Bucle infinito para bloquear la ejecución (fin del programa)

/* Función float_multiply: Multiplica dos números de punto flotante de 32 bits en r0 y r1 */
float_multiply:
    push   {r4-r7, lr}     @ Preservar registros callee-saved y enlace (Stack)
    mov    r4, r0          @ Guardar operando A en r4
    mov    r5, r1          @ Guardar operando B en r5

    @ Manejo de casos especiales antes de la multiplicación
    bl     check_special_cases   @ Llamar a función de casos especiales
    cmp    r1, #0               @ ¿Hubo caso especial? (r1 = 1 sí, r1 = 0 no)
    bne    _special_result      @ Si hubo caso especial, saltar a finalizar

    @ Paso 1: Extraer el signo, exponente y mantisa de los operandos
    @ (En r4 = A, r5 = B)
    eor    r6, r4, r5           @ XOR de ambos operandos (bit31) para obtener signo del resultado
    mov    r6, r6, LSR #31      @ r6 = signo_resultado (0 o 1)
    mov    r2, r4, LSR #23      @ r2 = exponente A (8 bits)
    mov    r3, r5, LSR #23      @ r3 = exponente B (8 bits)
    and    r2, r2, #0xFF        @ Mascara para obtener solo los 8 bits de exponente A
    and    r3, r3, #0xFF        @ Mascara para obtener solo los 8 bits de exponente B
    and    r4, r4, #0x7FFFFF    @ r4 = mantisa A (23 bits, sin bit implícito)
    and    r5, r5, #0x7FFFFF    @ r5 = mantisa B (23 bits, sin bit implícito)

    @ Paso 2: Añadir bit implícito (1) a las mantisas de números normales
    cmp    r2, #0
    beq    _A_subnormal
    orr    r4, r4, #0x800000    @ Si A no es cero/denormal, agregar 1 implícito (bit 23 = 1)
_A_subnormal:
    cmp    r3, #0
    beq    _B_subnormal
    orr    r5, r5, #0x800000    @ Si B no es cero/denormal, agregar 1 implícito (bit 23 = 1)
_B_subnormal:
    cmp    r2, #0
    moveq  r2, #1              @ Si A era denormal (exponente 0), ajustar exponente A = 1
    cmp    r3, #0
    moveq  r3, #1              @ Si B era denormal (exponente 0), ajustar exponente B = 1

    @ Paso 3: Multiplicar mantisas (sin signo) de 24 bits (incluyendo bit implícito)
    UMULL  r0, r1, r4, r5       @ Multiplicación 32x32 -> 64 bits (r1:r0 = mantisaA * mantisaB)

    @ Paso 4: Sumar exponentes (ajustando bias de 127)
    sub    r2, r2, #127         @ r2 = exponenteA + exponenteB - 127 (parcial: expA - 127)
    add    r2, r2, r3           @ r2 = exponenteA + exponenteB - 127 (suma completa)

    @ Paso 5: Normalizar el resultado si es necesario (ajustar mantisa y exponente)
    @ Verificar si el producto de mantisas tiene bit 47 = 1 (overflow de 24 bits)
    tst    r1, #0x8000          @ ¿Bit 47 del producto (bit15 de r1) es 1?
    beq    _no_norm
    @ Si bit47 = 1, desplazar mantisa a la derecha 1 bit y ajustar exponente +1
    mov    r9, r1, LSR #1       @ r9 = parte alta del producto >> 1
    mov    r10, r1, LSL #31     @ r10 = bit0 de r1 (bit32 del producto) aislado en bit31
    mov    r0, r0, LSR #1       @ desplazar parte baja >> 1
    orr    r0, r0, r10          @ insertar bit0 anterior de r1 como nuevo bit31 de r0
    mov    r1, r9               @ r1 = nueva parte alta desplazada
    add    r2, r2, #1           @ incrementar exponente en 1 (normalización)
_no_norm:
    @ Manejar underflow (resultado muy pequeño para representar en normalizado)
    cmp    r2, #1
    bge    _exp_ok              @ Si exponente >= 1, no hay underflow
    mov    r9, #1
    sub    r9, r9, r2           @ r9 = 1 - exponente (cantidad de bits a desplazar para subnormal)
    cmp    r9, #25
    bge    _underflow_zero      @ Si se requiere desplazar >= 25 bits, resultado es 0 (underflow total)
    @ Desplazar mantisa a la derecha (r9) bits para subnormalizar
_shift_loop:
    cmp    r9, #0
    beq    _shift_done
    mov    r10, r1, LSL #31     @ aislar bit0 de r1
    mov    r0, r0, LSR #1
    orr    r0, r0, r10          @ insertar bit0 de r1 como nuevo MSB de r0
    mov    r1, r1, LSR #1
    sub    r9, r9, #1
    b      _shift_loop
_shift_done:
    mov    r2, #0               @ exponente = 0 (subnormal)
    b      _after_adjust
_underflow_zero:
    @ Resultado underflow a cero (muy pequeño para subnormales)
    mov    r6, r6, LSL #31      @ construir ±0 según signo
    mov    r0, r6               @ r0 = ±0 (resultado final)
    b      _return_result

_exp_ok:
    @ Chequear overflow (exponente fuera de rango > 254)
    cmp    r2, #255
    blt    _after_adjust
    @ Resultado overflow a infinito
    mov    r0, #0               @ mantisa = 0
    mov    r2, #255             @ exponente = 255 (Inf)
    b      _after_adjust

_after_adjust:
    @ Paso 6: Empaquetar el resultado con signo, exponente y fracción
    mov    r8, r1, LSL #9       @ r8 = parte alta del producto << (32-23)
    mov    r0, r0, LSR #23      @ desplazar producto 64 bits a la derecha 23 posiciones
    orr    r0, r0, r8           @ combinar bits altos y bajos del producto alineado
    and    r0, r0, #0x7FFFFF    @ extraer 23 bits de fracción (ignorar bit implícito)
    lsl    r2, r2, #23          @ alinear exponente al campo [30:23]
    lsl    r6, r6, #31          @ alinear signo al bit 31
    orr    r0, r0, r2           @ insertar campo exponente
    orr    r0, r0, r6           @ insertar bit de signo

_return_result:
    pop    {r4-r7, pc}          @ Restaurar registros y regresar (resultado en r0)

_special_result:
    pop    {r4-r7, pc}          @ Regresar (resultado especial ya está en r0)

/* Función check_special_cases: Verifica casos especiales (0, Inf, NaN) */
check_special_cases:
    @ Comprobar casos especiales para operandos en r0 (A) y r1 (B)
    mov    r2, r0, LSR #23      @ exponente A
    and    r2, r2, #0xFF
    mov    r3, r1, LSR #23      @ exponente B
    and    r3, r3, #0xFF
    and    r4, r0, #0x7FFFFF    @ fracción A
    and    r5, r1, #0x7FFFFF    @ fracción B

    @ Caso NaN: Si A o B es NaN, devolver NaN
    cmp    r2, #0xFF
    beq    _check_A_nan
_check_A_nan:
    cmp    r2, #0xFF
    bne    _check_B_nan
    cmp    r4, #0
    bne    _A_is_nan           @ A es NaN (expo=255, frac≠0)
    @ A expo=255 pero frac=0 => A es Infinito, no NaN
_check_B_nan:
    cmp    r3, #0xFF
    bne    _check_zero_inf
    cmp    r5, #0
    bne    _B_is_nan           @ B es NaN (expo=255, frac≠0)
    @ B es Infinito si expo=255 y frac=0 (no NaN)

_A_is_nan:
    mov    r1, #1              @ flag especial
    bx     lr                  @ Resultado = A (NaN), se deja en r0 (ya está r0=A)

_B_is_nan:
    mov    r0, r1              @ Copiar NaN de B a r0
    mov    r1, #1              @ flag especial
    bx     lr

_check_zero_inf:
    @ Caso 0 * ∞ : Si un operando es 0 y el otro infinito => NaN
    cmp    r2, #0
    bne    _check_A_inf
    cmp    r4, #0
    bne    _check_A_inf        @ A no es cero (fracción ≠0), continuar
    @ A es cero
    cmp    r3, #0xFF
    beq    _inf_mul_zero       @ B es expo=255? Posible infinito
_check_A_inf:
    cmp    r3, #0
    bne    _check_B_inf
    cmp    r5, #0
    bne    _check_B_inf        @ B no es cero, continuar
    @ B es cero
    cmp    r2, #0xFF
    beq    _inf_mul_zero       @ A es infinito
_check_B_inf:
    @ Caso restantes: no activaron 0*∞
    @ Caso 0: Si cualquiera es 0 (y no se dio 0*∞), resultado 0
    cmp    r2, #0
    beq    _return_zero
    cmp    r3, #0
    beq    _return_zero

    @ Caso ∞: Si cualquiera es infinito (y no se dio 0*∞), resultado ∞ (con signo)
    cmp    r2, #0xFF
    beq    _return_inf
    cmp    r3, #0xFF
    beq    _return_inf

    @ No es caso especial
    mov    r1, #0              @ flag=0 (no se manejó caso especial)
    bx     lr

_inf_mul_zero:
    @ 0 * ∞ = NaN
    mov    r0, #0x7FC00000     @ Devolver NaN por defecto
    mov    r1, #1              @ flag especial
    bx     lr

_return_zero:
    @ 0 * (±finite) = 0 (con signo = XOR de signos de los operandos)
    mov    r12, r0, LSR #31
    mov    r8, r1, LSR #31
    eor    r12, r12, r8         @ signo = signA XOR signB
    mov    r0, r12, LSL #31     @ construir resultado ±0
    mov    r1, #1               @ flag especial
    bx     lr

_return_inf:
    @ (±finite) * (±∞) = ±∞ (signo = XOR de signos)
    mov    r12, r0, LSR #31
    mov    r8, r1, LSR #31
    eor    r12, r12, r8         @ signo = signA XOR signB
    mov    r0, r12, LSL #31
    orr    r0, r0, #0x7F800000  @ construir resultado ∞ (expo=255, frac=0)
    mov    r1, #1               @ flag especial
    bx     lr

.data
R:  dsl N                     @ Arreglo de resultados R[0..N-1] (N palabras de 32 bits)
A:  dcl 0xC1900000, 0x80800000, 0x1E2548FE, 0x23457242   @ Datos de entrada A[0..N-1]
B:  dcl 0x41180000, 0x3F800000, 0x211145A2, 0x12453010   @ Datos de entrada B[0..N-1]

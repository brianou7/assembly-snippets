// https://developer.arm.com/documentations
.global _start
// .equ N, 5
.equ N, 2
.equ TRUE, 1
.equ NAN, 0x7FFFFFFF
.equ INF, 0x7F800000
.equ ZERO, 0x00000000
.text

_start:
    ldr r4, =A          // Cargar dirección donde se encuentra el primer valor de A
    ldr r5, =B          // Cargar dirección donde se encuentra el primer valor de B
    mov r6, #N          // Cargar el número de operación a realizar
    ldr r7, =R          // Cargar dirección donde se almacenará el primer resultado R

/* LOOP N */
loop:
    /* Leer A[i] y B[i]: como argumentos de función: r0, r1 */
    ldr r0, [r4], #4			// Cargar A[i] en r0 y actualizar puntero A en la siguiente posición de memoria
    ldr r1, [r5], #4    		// Cargar B[i] en r1 y actualizar puntero B en la siguiente posición de memoria
    /* Algoritmo para realizar R[i] = A[i] * B[i] 
       El programa deberá tener al menos dos funciones que serán llamadas durante la ejecución.
       Dichas funciones deberán emplear el Stack para mantener el valor de los registros 
       que se deberán preservar de acuerdo con la convención de regs. */
    bl check_special_cases      // Llamar a función para verificar casos especiales (0, Inf, NaN)
    cmp r1, #TRUE               // Comparar bandera de casos especiales
	beq _save_product			// Si aplicó un caso especial, almacenar resultado y continuar a la siguiente iteración.
    bl	multiply				// Multiplicar operandos....
    /* Almacenar R[i] */
_save_product:
    str    r0, [r7], #4    		// Almacenar resultado en R[i] y actualiazr puntero R en la siguiente posición de memoria.
    subs r6, r6, #1             // Decrementar contador de operaciones.
    bne loop                    // Repetir mientras las operaciones sean diferentes de cero

finish:
    b finish                	// loop infinito para bloquear ejecución

/*
* Determinar si los operandos se encuentran normalizados, en caso de que no normalizar.
* Aplicar operación en formato de punto flotante de precisión simple:
*/
multiply:
    push {r4-r9, lr}            // Preservar registros y enlace en el Stack
    mov r4, r2
	mov r5, r3
    bl get_sign                 // Obtener signo del resultado: sign(A) XOR sign(B)
    mov r12, r0                  // Guardar Signo(R) en r12

	mov r7, r5
	ldr r11, =0x7FFFFF           // Cargar la constante 0x7FFFFF (mascara fracción) en un registro.
	// Paso 1:
	// Extraer componentes de A y B.
	mov r0, r4
	bl extract_components		// Extraer componentes de A[i]
	mov r4, r1					// A: Signo
	mov r5, r2					// A: Exponente
	mov r6, r3					// A: Fracción
	mov r0, r7
	bl extract_components		// Extraer componentes de B[i]
	mov r7, r1					// B: Signo
	mov r8, r2					// B: Exponente
	mov r9, r3					// B: Fracción    
	// Paso 2:
	// Agregar 1 en el bit más significativo de las fracciones de A y B para formar las Mantisas.
    cmp	r5, #0					// Comparar Expo(A) con 0...
    beq	_normalize_A			// Si: 	 Expo(A) == 0 => A no está normalizado.
    orr	r6, r6, #0x800000    	// Sino: Expo(A) != 0 => A está normalizado. Agregar 1 al bit más significativo de la fracción: Mantisa!
    cmp	r8, #0					// Comparar Expo(B) con 0...
    beq	_normalize_B			// Si: 	 Expo(B) == 0 => B no está normalizado.
    orr	r9, r9, #0x800000		// Sino: Expo(B) != 0 => B está normalizado. Agregar 1 al bit más significativo de la fracción: Mantisa!
	b _both_normalized
_normalize_A:
    mov	r5, #1              	// Agregar 1 al exponente de A para normalizar!
_normalize_B:
    mov	r8, #1              	// Agregar 1 al exponente de B para normalizar!
_both_normalized:
	// Paso 4:
	// Multiplicar Mantisas (fracciones normalizadas) de 24 bits.
    umull r0, r1, r6, r9		// Multiplicar Mantisa(A)[32-bits] * Mantisa(B)[32-bits] -> Mantisa(R)[64-bits]
	// Paso 4: Sumar exponentes con ajuste de sesgo: 127. Expo(R) = Expo(A) + Expo(B) - 127 exponenteA + exponenteB - 127
    sub	r5, r5, #127			// Expo(A) = Expo(A) - 127
    add	r5, r5, r8           	// Expo(A) = Expo(A) + Expo(B) = Expo(R)
    // Paso 5:
	// Normalizar Mantisa resultante y ajustar exponente si es necesario.
    tst	r1, #0x8000				// Verificar si Mantisa(R)[64-bits] está en el rango de valores representables.
    beq	_no_norm				// Si: 	 bit#47 == 1 (overflow de 24 bits). El bit 47 del producto corresponde al bit15 de r1.
    mov r9, r1, LSR #1          // Sino: bit#47 != 1 => Desplazar Mantisa 1 bit a la derecha y ajustar exponente +1... 	@ r9 = parte alta del producto >> 1
    mov r10, r1, LSL #31        // r10 = bit0 de r1 (bit32 del producto) aislado en bit31
    mov r0, r0, LSR #1          // Desplazar parte baja >> 1
    orr r0, r0, r10             // Insertar bit0 anterior de r1 como nuevo bit31 de r0
    mov r1, r9                  // r1 = nueva parte alta desplazada
    add r5, r5, #1              // incrementar exponente en 1 (normalización)

_no_norm:						// Manejar underflow (resultado muy pequeño para representar en normalizado)
    cmp	r5, #1					// Verificar que Expo(R) sea mayor que el limite inferior representable.
    bge _is_expo_R_ok			// Si: 	 Expo(R) >= 1 => Está correcto. No hay underflow!
    mov r2, #1				    // Sino: Expo(R) <  1 => Hay underflow! (Fuera de rango) 
    sub r2, r2, r5              // r9 = 1 - exponente (cantidad de bits a desplazar para subnormal)
    cmp r2, #25                 // Verificar que la cantidad de bits a desplazar sea menor que 25.
    bge _underflow_zero         // Si se requiere desplazar más de 25 bits, el resultado es 0 (Underflow)
                                // Desplazar Mantisa a la derecha (r9) bits para subnormalizar
_shift_loop:
    cmp r2, #0
    beq _shift_done
    mov r10, r1, LSL #31        // Aislar bit0 de r1
    mov r0, r0, LSR #1
    orr r0, r0, r10             // Insertar bit0 de r1 como nuevo MSB de r0
    mov r1, r1, LSR #1
    sub r2, r2, #1
	b	_shift_loop
_shift_done:
    mov r5, #0                  // Expo(R) = 0 (Denormalizado)
    b _assamble
_underflow_zero:
    // Resultado underflow a cero (muy pequeño para No Normalizado)
    mov r12, r12, LSL #31        // Construir ±0 según signo
    mov r0, r12                  // r0 = ±0 (resultado final)
    b _return_product
_is_expo_R_ok:
    cmp r5, #255				// Verificar que Expo(R) sea menor que el limite superior representable.
    blt _assamble               // Si: Expo(R) < 255 ==> Está correcto. No hay overflow! (Se encuentra en el rango)
    ldr r5, =INF                // Expo(R) -> Infinito (Overflow)
    mov r0, #0                  // Mantisa = 0
    b _assamble
_assamble:
    // Paso 6:
    // Ensamblar el resultado: signo, exponente y fracción
    mov r8, r1, LSL #9          // r8 = parte alta del producto << (32-23)
    mov r0, r0, LSR #23         // Desplazar producto 64 bits a la derecha 23 posiciones
    orr r0, r0, r8              // Concatenar bits altos y bajos del producto alineado
    ldr r9, =0x7FFFFF           // Cargar máscara de 23 bits para la fracción
    and r0, r0, r9              // Extraer 23 bits de fracción (ignorar bit implícito)
    lsl r5, r5, #23             // Alinear exponente al campo [30:23]
    lsl r12, r12, #31           // Alinear signo al bit 31 correspondiente
    orr r0, r0, r5              // Insertar campo exponente
    orr r0, r0, r12             // Insertar bit de signo

_return_product:
    pop    {r4-r9, pc}          @ Restaurar registros y regresar (resultado en r0)

/*
* Verifica casos especiales determinados por los operandos, como son: 0, NaN o Inf.
* Los operandos se encuentran en los registros correspondientes: r0=(A) y r1=(B)
*/
check_special_cases:
    push {r4-r7, lr}            // Preservar registros y enlace en el Stack
	mov r4, r0					// A[i]
	mov r5, r1					// B[i]
	push {r4-r5}
	ldr r11, =0x7FFFFF           // Cargar la constante 0x7FFFFF (mascara fracción) en un registro.
	// Verificar caso de A[i]
	bl extract_components		// Extraer componentes de A[i]
	bl check_operator			// Verificar valor de A
	mov r7, r0					// Asignar retorno de caso A
	// Verificar caso de B[i]
	mov r0, r5					// Asignar B[i] como argumento de función extract_components(x)
	bl extract_components		// Extraer componentes de B[i]
	bl check_operator			// Verificar valor de B
	mov r8, r0					// Asignar retorno de caso B

	mov r1, r7					// a = A[i]
	mov r2, r8					// b = B[i]
	bl is_signed_NaN_case		// Revisar si aplica caso especial: r = Signed NaN.
	mov r1, r8					// a = B[i]
	mov r2, r7					// b = A[i]
	bl is_signed_NaN_case		// Revisar si aplica caso especial: +-NaN (Operadores invertidos).

	mov r1, r7					// a = A[i]
	mov r2, r8					// b = B[i]
	bl is_NaN_case				// Revisar si aplica caso especial: r = NaN.
	bl is_infinite_case_1		// Revisar si aplica caso especial: r = +-Infinite (Operadores iguales).
	bl is_infinite_case_2		// Revisar si aplica caso especial: r = +-Infinite (Operadores diferentes).
	bl is_special_NaN_case		// Revisar si aplica caso especial: r = NaN (Cero e Infinito).
	bl is_zero_case				// Revisar si aplica caso especial: r = 0 (Cero e Infinito).

	mov r1, r8					// a = B[i]
	mov r2, r7					// b = A[i]
	bl is_infinite_case_2		// Revisar si aplica caso especial: +-Infinite (Operadores diferentes + Operadores invertidos).	
	bl is_special_NaN_case		// Revisar si aplica caso especial: r = NaN (Cero e Infinito + Operadores invertidos).
	bl is_zero_case				// Revisar si aplica caso especial: r = 0 (Cero e Infinito + Operadores invertidos).
	b _return					// No se aplicó ningún caso especial!
get_sign:
	mov r1, r4, LSR #31			// Extraer signo de A
	mov r2, r5, LSR #31			// Extraer signo de B
	eor r0, r1, r2	            // Determinar signo del producto
	mov pc, lr					// Regresar al llamado de la función: Siguiente instrucción

extract_components:
	mov r1, r0, LSR #31			// Extraer signo de A
    mov r2, r0, LSR #23			// Extraer exponente de A: Desplazar 23 bits a la derecha para descartar la fracción de A
    and r2, r2, #0xFF           // Aplicar mascara de 8 bits para obtener el exponente de A.
    and r3, r0, r11             // Aplicar mascara de 23 bits para obtener solo la fracción de A.
	mov pc, lr					// Regresar

check_operator:
	cmp r0, #0					// Comparar operador con 0
	beq _is_zero				// Si: 	 x == 0 => Es cero!
	cmp r2, #0					// Comparar exponente con 0
	beq _is_no_norm				// Si 	 Expo(x) == 0 => Es finito no normalizado!
    cmp r2, #0xFF               // Sino: Comparar exponente con 11111111
    beq _is_infinite_or_nan		// Si: 	 Expo(x) == 11111111 => Es Infinito o NaN!
    b _is_finite	           	// Sino: Frac(x) == 0 => Es Finito!

_is_zero:
	mov r0, #0					// Constante para caso cero
	b _check_operator_return	// Retornar caso
_is_no_norm:
	mov r0, #1					// Constante para caso finito no normalizado
	b _check_operator_return	// Retornar caso
_is_finite:
	mov r0, #2					// Constante para caso finito normalizado
	b _check_operator_return	// Retornar caso
_is_infinite_or_nan:
	cmp r3, #0                  // Comparar fracción con 0
    bne _is_nan           		// Si:	 Frac(x) != 0 => Es NaN!
								// Sino: Frac(x) == 0 => Es Infinito! Continuar..
_is_infinite:
	mov r0, #3					// Constante para caso infinito
	b _check_operator_return	// Retornar caso
_is_nan:
	mov r0, #4					// Constante para caso NaN
	b _check_operator_return	// Retornar caso

_check_operator_return:
	mov pc, lr					// Retorno de función. Valor en r0

/* Special cases */

reset_auxs:
	mov r0, #0					// Inicializar aux en 0 
	mov r3, #0					// Inicializar aux en 0
	mov pc, lr					// Regresar a caso.

is_signed_NaN_case:				// func(a,b) -> +-(r)
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #3					// Si a == 3
	moveq r0, #TRUE            	// => A = Infinito
	cmp r2, #4					// Si b == 4
	moveq r3, #TRUE            	// => B = NaN
	and r0, r0, r3				// Operar: a AND b
	cmp r0, #TRUE				// Si A AND B => r = signed NaN
	bne	_cases_return			// Regresar a función de casos especiales: Verificar siguiente caso.

	bl get_sign					// Obtener signo para r (sign(A) XOR sign(B))
	ldr r1, =NAN				// Obtener valor para r (NaN)
	
	mov r0, r0, LSL #31			// Colocar signo de r en el bit más significativo.
    orr r0, r0, r1				// Concatenar signo y valor correspondientes.
    b   _flag                   // Encender bander de caso especial y retornar resultado.
is_NaN_case:					// func(a,b) -> r
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #4					// Si a == 4
	moveq r0, #TRUE            	// => A = NaN
	cmp r2, #4					// Si b == 4
	moveq r3, #TRUE            	// => B = NaN
	orr r0, r0, r3				// Operar: a OR b
	cmp r0, #TRUE				// Si (a == 4) OR (b == 4) => r = NaN
	bne	_cases_return			// Regresar a función de casos especiales: Verificar siguiente caso.

	ldr r0, =NAN				// Obtener valor para r (unsigned NaN)
    b   _flag                   // Encender bander de caso especial y retornar resultado.
is_special_NaN_case:
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #0					// Si a == 0
	moveq r0, #TRUE            	// => A = 0
	cmp r2, #3					// Si b == 3
	moveq r3, #TRUE            	// => B = Infinito
	and r0, r0, r3				// Operar: a AND b
	cmp r0, #TRUE				// Si: (a == 0) OR (b == Finite) => r = NaN
	bne	_cases_return			// Sino: Regresar a función de casos especiales: Verificar siguiente caso.

	ldr r0, =NAN				// Obtener valor para r (unsigned NaN)
    b   _flag                   // Encender bandera de caso especial y retornar resultado.

is_infinite_case_1:				// func(a,b) -> r
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #3					// Si a == 3
	moveq r0, #TRUE            	// => A = Inf
	cmp r2, #3					// Si b == 3
	moveq r3, #TRUE            	// => B = Inf
	and r0, r0, r3				// Operar: a AND b
	cmp r0, #TRUE				// Si (a == Inf) AND (b == Inf) => r = +-(Inf)
	bne	_cases_return
	b _return_infinite
is_infinite_case_2:				// func(a,b) -> r
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #2					// Si a == 2
	moveq r0, #TRUE            	// => A = Finite
	cmp r2, #3					// Si b == 4
	moveq r3, #TRUE            	// => B = Inf
	and r0, r0, r3				// Operar: a AND b
	cmp r0, #TRUE				// Si (a == Inf) AND (b == Inf) => r = +-(Inf)
	bne	_cases_return
	b _return_infinite
_return_infinite:
	bl get_sign					// Obtener signo para r (sign(A) XOR sign(B))
	ldr r1, =INF				// Obtener valor para r (Inf)

	mov r0, r0, LSL #31			// Colocar signo de r en el bit más significativo.
    orr r0, r0, r1				// Concatenar signo y valor correspondientes.
    b   _flag                   // Encender bander de caso especial y retornar resultado.

is_zero_case:
	push {lr}
	bl reset_auxs				// Reinicializar valores por defecto de los registros auxiliares.
	cmp r1, #0					// Si a == 0
	moveq r0, #TRUE            	// => A = 0
	cmp r2, #2					// Si b == 2
	moveq r3, #TRUE            	// => B = Finito
	and r0, r0, r3				// Operar: a AND b
	cmp r0, #TRUE				// Si: (a == 0) OR (b == Finite) => r = NaN
	bne	_cases_return			// Sino: Regresar a función de casos especiales: Verificar siguiente caso.

	ldr r0, =ZERO				// Obtener valor para r = 0 (Cero).
    b   _flag                   // Encender bandera de caso especial y retornar resultado.

_cases_return:
	pop {pc}

_flag:
	pop {lr}
    mov r1, #TRUE               // Bandera para indicar que se manejó un caso especial.
    b _return                   // Retorno de función: r0
_return:
	pop {r2-r3}
    pop {r4-r7, pc}             // Restaurar registros (resultado en r0) y regresar a la siguiente instrucción.

.data
R:  .ds.l N                 // Reservar espacio para los productos
// Valores A: [8.750122E-21, 1.07035864E-17]
A:  .dc.l 0x1E2548FE, 0x23457242
// Valores B: [4.922007E-19, 6.222148E-28]
B:  .dc.l 0x211145A2, 0x12453010

// Valores A: [NaN, NaN, -Inf, +Inf, -18.0, -1.1754944E-38, 8.750122E-21, 1.07035864E-17]
//A:  .dc.l 0x7FFFFFFF, 0x7FFFFFFF, 0xFF800000, 0x7F800000, 0xC1900000, 0x80800000, 0x1E2548FE, 0x23457242

// Valores B: [-Inf, +Inf, NaN, NaN, 9.5, 1.0, 4.922007E-19, 6.222148E-28]
//B:  .dc.l 0xFF800000, 0x7F800000, 0x7FFFFFFF, 0x7FFFFFFF, 0x41180000, 0x3F800000, 0x211145A2, 0x12453010
// Valores R: [-NaN, +NaN, -Inf, +Inf, -18.0, -1.1754944E-38, 8.750122E-21, 1.07035864E-17]
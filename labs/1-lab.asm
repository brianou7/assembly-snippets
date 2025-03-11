.global _start
	.equ    MAXMN, 5
	.equ    MINMN, 2
	.text
_start:
    /* Inicio del programa:
    * Inicialiazión de registros y lectura de valores requeridos desde la memoria
    */
	mov r0, #0				// Auxiliar para casos. Inicia en 0
	mov r1, #MINMN			// Cargar el número minimo de filas/columnas definido por dominio en r1
	mov r2, #MAXMN			// Cargar el número maximo de filas/columnas definido por dominio en r2

_check:						// Switch/Case para validar dominios de MA, NA, MB y NB
	cmp r0, #0				// Caso r0 = 0
	beq _check_MA			// Chequear MA
	cmp r0, #1				// Caso r0 = 1
	beq _check_NA			// Chequear NA
	cmp r0, #2				// Caso r0 = 2
	beq _check_MB			// Chequear MB
	cmp r0, #3				// Caso r0 = 3
	beq _check_NB			// Chequear NB
	b _check_mul_condition	// Chequear que MatA se pueda multiplar con MatB

_check_MA:
	ldr r3,	=MA			// Cargar la dirección en memoria del objeto MA en r3
	ldr r3,	[r3]		// Cargar el número de filas de MatA en r3
	b _check_domain		// Validar que MINMN <= MA <= MAXMN

_check_NA:
	ldr r3,	=NA			// Cargar la dirección en memoria del objeto MA en r3
	ldr r3,	[r3]		// Cargar el valor del número de columnas de MatA en r3
	b _check_domain		// Validar que MINMN <= NA <= MAXMN

_check_MB:
	ldr r3,	=MB			// Cargar la dirección en memoria del objeto MB en r3
	ldr r3,	[r3]		// Cargar el valor del número de filas de MatB en r3
	b _check_domain		// Validar que MINMN <= MB <= MAXMN

_check_NB:
	ldr r3,	=NB			// Cargar la dirección en memoria del objeto NB en r3
	ldr r3,	[r3]		// Cargar valor del número de columnas de MatB en r3
	b _check_domain		// Validar que MINMN <= NB <= MAXMN

_check_domain:
	cmp r3, r1			// Comparar MN con MINMN
	blt abort			// Si MN < MINMN, abortar programa
	cmp r3, r2			// Comparar MA con MAXMN
	bgt abort			// Si MN > MAXMN, abortar programa
	add r0, r0, #1		// Aumentar en 1 variable auxiliar de casos: Siguiente caso de chequeo
	b _check			// Volver a evaluación de casos

_check_mul_condition:
	mov r3, #0			// Limpiar registro r3 para facilidad de entendimiento de los registros
	ldr r1, =NA			// Cargar la dirección en memoria del objeto NA en el registro auxiliar r1
	ldr r1, [r1]		// Cargar el valor del número de columnas de MatA en el registro auxiliar r1
	ldr r2, =MB			// Cargar la dirección en memoria del objeto MB en el registro auxiliar r2
	ldr r2, [r2]		// Cargar el valor del número de filas de MatB en el registro auxiliar r2
	cmp r1, r2			// Comparar número de columnas de MatA (NA) con el número filas de MatB (MB)
	bne abort			// Si NA != MB, abortar programa

_compute_MR:
	ldr r1, =MA			// Cargar la dirección en memoria del objeto MA en r1
	ldr r1, [r1]		// Cargar el valor del número de filas de MatA en r1
	ldr r2, =MR			// Cargar la dirección en memoria del objeto MR en r2
	str r1, [r2, #0]	// Almacenar en memoria el número de filas de MatR: MR = MA
_compute_NR:
	ldr r1, =NB			// Cargar la dirección en memoria del objeto NB en r1
	ldr r1, [r1]		// Cargar el valor del número de columnas de MatB en r1
	ldr r2, =NR			// Cargar la dirección en memoria del objeto NR en r2
	str r1, [r2, #0]	// Almacenar en memoria el número de columnas de MatR: NR = NB
	
    /* Cuerpo del programa:
    * Código principal para realizar la operación R = A * B, donde A y B son
    * matrices de 32-bits con signo y R es una matriz de 64-bits con signo.
    */
	mov r0, #0			// Limpiar registro r0 para facilidad de entendimiento de los registros
	ldr r1, =MatA		// Cargar la dirección en memoria de MatA[0]
	ldr r2, =MatB		// Cargar la dirección en memoria de MatB[0]
	ldr r3, =MatR		// Cargar la dirección en memoria de MatR[0]
	ldr r9, =MB			// Reinicio: Cargar la dirección en memoria del objeto MB en r9
	ldr r9, [r9]		// Cargar valor del número de filas de MatB en r9
	mov r8, #4			// Cargar el valor inmediato #4 en r4 para posterior multiplicación
	mov r11, #0			// Auxiliar/contador de posición de fila MatA: i =0
	mov r12, #0			// Auxiliar/contador de posición de columna MatB: j = 0
	b _row_loop

_next_row:
	add r11, r11, #1	// i++
	mov r12, #0			// Limpiar r12 e inicializar en 0. Auxiliar columnas: j = 0

	ldr r0, =MA			// Reinicio: Cargar la dirección en memoria del objeto MA en r0
	ldr r0, [r0]		// Cargar el valor del número de filas de MatA en r0
	ldr r9, =MB			// Reinicio: Cargar la dirección en memoria del objeto MB en r9
	ldr r9, [r9]		// Cargar el valor del número de filas de MatB en r9

	cmp r11, r0			// Si: i == MA sino: Reposicionar MatB
	bge	_continue		// Salir del ciclo

	ldr r2, =MatB		// Reposicionar MatB: Cargar la dirección en memoria de MatB[0]
	mov r0, #0			// Limpiar r0 e inicializar en 0. Acumulador MatR[i] LSB
	mov r10, #0			// Limpiar r10 e inicializar en 0. Acumulador MatR[i] MSB
	b _row_loop

_next_col:
	ldr r9, =MB			// Reinicio: Cargar la dirección en memoria del objeto MB en r9
	ldr r9, [r9]		// Cargar el valor del número de filas de MatB en r9

	mul r0, r9, r8		// Calcular cantidad de bytes a desplazar a la izquierda para reposicionar MatA
	sub r1, r1, r0		// Desplezar posición de memoria al inicio de la fila M de MatA: MatA[i-4]

	mov r0, #0			// Limpiar r0 e inicializar en 0
	mov r10, #0			// Limpiar r10 e inicializar en 0
	ldr r2, =MatB		// Dirección en memoria de MatB[0]
	mul r6, r8, r12		// Calcular siguiente posición en memoria (4 * n) para la siguiente columna de MatB
	add r2, r2, r6		// Actualizar registro en la posición de la siguiente columna

_row_loop:
	ldr r4, [r1]			// Valor en MatA[i]
	ldr r5, [r2]			// Valor en MatB[j]
	smull r6, r7, r4, r5	// Operar: MatA[i] * MatB[j] -> MatR[i][i+4] 64 bits
	adds r0, r0, r6			// Sumar parte baja (LSB)
	adc r10, r10, r7		// Sumar parte alta (MSB)

	add r1, r1, r8			// Calcular la siguiente posición en memoria de MatA: Mat[i+1]
	ldr r6, =NB				// Cargar la dirección en memoria de NB
	ldr r6, [r6]			// Cargar de la memoria la cantidad de columnas de MatB = NB
	mul r6, r8, r6			// Calcular la siguiente posición en memoria de MatB: NB * 4 bytes
	add r2, r2, r6			// Calcular la siguiente dirección en memoria de MatB: MatB[j+1]

	subs r9, r9, #1			// k--
	bne _row_loop			// Siguiente iteración
							// Almacenar MatR[j][j+4]... little-endian: LSB-MSB
	str r0, [r3]			// Almacenar MatR[j]: LSB...
	str r10, [r3, #4]		// Almacenar MatR[j+4]: MSB
	add r3, r3, r8			// Calcular la siguiente posicion de memoria de MatR: [MatR] + 4 (x1)
	add r3, r3, r8			// Calcular la siguiente posicion de memoria de MatR: [MatR] + 4 (x2)
	add r12, r12, #1		// l++

	ldr r6, =NA				// Cargar la dirección en memoria del objeto NA en r6
	ldr r6, [r6]			// Cargar el número de columnas de MatA en r6
	cmp r12, r6				// Si i == NA
	beq _next_row			// Siguiente fila de MatA
	b _next_col				// Siguiente columna de MatB

_continue:
	b finish
    /* Fin del programa:
    * Bucle infinito para evitar la búsqueda de nuevas instrucciones
    */
abort:
	ldr r0, =0xFFAAFFAA	// Caragar el código de error en el registro auxiliar r0
	ldr r3, =MatR		// Cargar la dirección en memoria del primer elemento de MatR
	str r0, [r3]		// Almacenar el código de error en la primera posición de MatR
	b finish

finish:
    b finish

.data
	/* Constantes y variables propias:
	* Utilice esta zona para declarar sus constantes y vairables requerida
	*/

	/* Constantes y variables dadas por el profesor (Ej. A es 3x3 y B es 3x1):
	* Esta zona contiene los tamaños y valores de las matrices A, B, además
	* de la zona de memoria donde se generará los valores de R
	*/
	MA:     .dc.l   3
	NA:     .dc.l   3
	MatA:   .dc.l   -58451,	21542,	53654
			.dc.l   4575,	211551,	-9854512
			.dc.l   -12457,	21542,	-36595
	MB:     .dc.l   3
	NB:     .dc.l   1
	MatB:   .dc.l   -54842
			.dc.l   24515
			.dc.l   54421
	MR:     .ds.l   1
	NR:     .ds.l   1
	MatR:   .ds.l   (MAXMN*MAXMN*2)
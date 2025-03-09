.global _start
	.equ    MAXMN, 5
	.equ    MINMN, 2
	.text
_start:
    /* Inicio del programa:
    * Inicialiazión de registros y lectura de valores requeridos desde la memoria
    */
	mov r0, #0
	mov r1, #0
	mov r2, #0
	mov r1, #MINMN		// Cargar el número minimo de filas/columnas definido por dominio en r1
	mov r2, #MAXMN		// Cargar el número maximo de filas/columnas definido por dominio en r2
	ldr r3, =MatR
	
	ldr r9,	=MA			// Cargar la dirección en memoria del objeto MA en r9
	ldr r9,	[r9]		// Cargar el número de filas de MatA en r9
	ldr r10, =NA		// Cargar la dirección en memoria del objeto NA en r10
	ldr r10, [r10]		// Cargar el número de columnas de MatA en r10
	ldr r11, =MB		// Cargar la dirección en memoria del objeto MB en r11
	ldr r11, [r11]		// Cargar el número de filas de MatB en r11
	ldr r12, =NB		// Cargar la dirección en memoria del objeto NB en r12
	ldr r12, [r12]		// Cargar el número de columns de MatB en r12

_check_domain:
	cmp r9, r1			// Comparar MA con MINMN
	blt abort			// Si MA < MINMN, abortar programa
	cmp r9, r2			// Comparar MA con MAXMN
	bgt abort			// Si MA > MAXMN, abortar programa

	cmp r11, r1			// Comparar MB con MINMN
	blt abort			// Si MB < MINMN, abortar programa
	cmp r11, r2			// Comparar MB con MAXMN
	bgt abort			// Si MB > MAXMN, abortar programa

	cmp r10, r1			// Comparar NA con MINMN
	blt abort			// Si NA < MINMN, abortar programa
	cmp r10, r2			// Comparar MA con MAXMN
	bgt abort			// Si MA > MAXMN, abortar programa

	cmp r12, r1			// Comparar NB con MINMN
	blt abort			// Si NB < MINMN, abortar programa
	cmp r12, r2			// Comparar MB con MAXMN
	bgt abort			// Si NB > MAXMN, abortar programa

_check_mul_condition:
	ldr r1, =NA			// Cargar la dirección en memoria del objeto NA en el registro auxiliar r1
	ldr r1, [r1]		// Cargar el número de columnas de MatA en el registro auxiliar r1
	ldr r2, =MB			// Cargar la dirección en memoria del objeto MB en el registro auxiliar r2
	ldr r2, [r2]		// Cargar el número de filas de MatB en el registro auxiliar r2
	cmp r1, r2			// Comparar número de columnas de MatA con el número filas de MatB
	bne abort			// Si NA != MB, abortar programa

	ldr r1, =MA			// Cargar la dirección en memoria del objeto MA en r1
	ldr r1, [r1]		// Cargar el número de filas de MatA en r1
	ldr r2, =MR			// Cargar la dirección en memoria del objeto MR en r2
	str r1, [r2, #0]	// Almacenar en memoria el número de filas de MatR

	ldr r1, =NB			// Cargar la dirección en memoria del objeto NB en r1
	ldr r1, [r1]		// Cargar el número de columnas de MatB en r1
	ldr r2, =NR			// Cargar la dirección en memoria del objeto NR en r2
	str r1, [r2, #0]	// Almacenar en memoria el número de columnas de MatR
	
    /* Cuerpo del programa:
    * Código principal para realizar la operación R = A * B, donde A y B son
    * matrices de 32-bits con signo y R es una matriz de 64-bits con signo.
    */
	ldr r1, =MatA		// MatA[0]
	mul r0, r9, r10		// MA * MB 
	add r0, r0, #2		// MatB[0] = MA * MB + 2

_operation:
	ldr 
    /* Fin del programa:
    * Bucle infinito para evitar la búsqueda de nuevas instrucciones
    */
abort:
	ldr r0, =0xFFAAFFAA	// Caragar el código de error en el registro auxiliar r0
	str r0, [r3, #0]	// Store abort code in MatR
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
	MatA:   .dc.l   -58451, 21542,  53654
			.dc.l   4575,   211551, -98545212
			.dc.l   -12457, 21542,  -36595
	MB:     .dc.l   3
	NB:     .dc.l   2
	MatB:   .dc.l   -54842, 1
			.dc.l   24515,	1
			.dc.l   54421,	1
	MR:     .ds.l   1
	NR:     .ds.l   1
	MatR:   .ds.l   (MAXMN*MAXMN*2)

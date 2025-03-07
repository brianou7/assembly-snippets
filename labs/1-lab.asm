.global _start
    .equ    MAXMN, 5
    .equ    MINMN, 2
    .text
_start:
    /* Inicio del programa:
    * Inicialiazión de registros y lectura de valores requeridos desde la memoria
    */

    /* Cuerpo del programa:
    * Código principal para realizar la operación R = A * B, donde A y B son
    * matrices de 32-bits con signo y R es una matriz de 64-bits con signo.
    */

    /* Fin del programa:
    * Bucle infinito para evitar la búsqueda de nuevas instrucciones
    */
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
NB:     .dc.l   1
MatB    .dc.l   -54842
        .dc.l   24515
        .dc.l   54421
MR:     .ds.l   1
NR:     .ds.l   1
MatR:   .ds.l   (MAXMN*MAXMN*2)

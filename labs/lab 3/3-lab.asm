.text
    .global _start         @ Declarar punto de entrada global

_start: 
    @ **** Inicialización de registros base para periféricos ****
    LDR r8, =0xFF200000    @ Cargar en r8 la dirección base de los LEDs rojos (LEDR)
    LDR r9, =0xFF200040    @ Cargar en r9 la dirección base de los switches (SW)
    LDR r10, =0xFF200050   @ Cargar en r10 la dirección base de los pulsadores (KEY)
    LDR r11, =0xFF200020   @ Cargar en r11 la dirección base de los displays de 7 segmentos (HEX3-HEX0)

@ **** Fase A: Ingreso del operando A ****
stageA:
    MOV r0, #0x00          @ Primero apagar todos los displays
    STR r0, [r11, #4]      @ Apagar HEX1
    STR r0, [r11, #8]      @ Apagar HEX2
    STR r0, [r11, #12]     @ Apagar HEX3
    
    MOV r0, #0x77          @ Cargar en r0 el patrón 0x77 que representa la letra 'A' en 7 segmentos
    STR r0, [r11]          @ Mostrar la letra 'A' en el display de 7 segmentos HEX0
    
A_input_loop:
    LDR r1, [r9]           @ Leer el valor de los switches (SW9-0) en r1
    AND r1, r1, #0xFF      @ Enmascarar para obtener solo 8 bits (SW7-0) del operando A
    STR r1, [r8]           @ Escribir el valor de 8 bits en los LEDs (LED7-0 muestran el binario de A)
    
    LDR r0, [r10]          @ Leer el estado de los pulsadores (KEY3-0) en r0
    ANDS r0, r0, #0x1      @ Aislar el bit0 (KEY0) y actualizar flags
    BEQ A_input_loop       @ Si KEY0 no está presionado (==0), seguir loop esperando confirmación de A
    
    @ Si KEY0 está presionado, salir del bucle: el operando A se confirma
    
    @ Almacenar A en R2 con signo extendido a 32 bits usando LSL/ASR
    MOV r2, r1             @ Primero copiamos el valor a r2
    LSL r2, r2, #24        @ Desplazar el valor 24 bits a la izquierda (bit7 pasa a bit31)
    ASR r2, r2, #24        @ Desplazar aritméticamente 24 bits a la derecha (extender signo)

    @ Esperar a que el usuario suelte el botón antes de continuar (evita lecturas múltiples por mantener pulsado)
A_release_wait:
    LDR r0, [r10]          @ Leer estado actual del pulsador KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BNE A_release_wait     @ Si KEY0 sigue presionado (==1), esperar aquí hasta que se suelte

@ **** Fase B: Ingreso del operando B ****
    MOV r0, #0x7C          @ Cargar en r0 el patrón 0x7C que representa la letra 'b' en 7 segmentos
    STR r0, [r11]          @ Mostrar la letra 'b' en el display de 7 segmentos HEX0
    
B_input_loop:
    LDR r1, [r9]           @ Leer el valor de los switches (SW9-0) en r1 para operando B
    AND r1, r1, #0xFF      @ Enmascarar a 8 bits (SW7-0) para obtener el valor de B
    STR r1, [r8]           @ Mostrar el valor de B en los LEDs (LED7-0)
    
    LDR r0, [r10]          @ Leer estado de pulsadores (KEY)
    ANDS r0, r0, #0x1      @ Aislar bit0 (KEY0) y actualizar flags
    BEQ B_input_loop       @ Repetir loop mientras no se presione el botón de confirmación para B (==0)

    @ Almacenar B en R3 con signo extendido a 32 bits usando LSL/ASR
    MOV r3, r1             @ Primero copiamos el valor a r3
    LSL r3, r3, #24        @ Desplazar el valor 24 bits a la izquierda (bit7 pasa a bit31)
    ASR r3, r3, #24        @ Desplazar aritméticamente 24 bits a la derecha (extender signo)

    @ Esperar liberación del botón antes de mostrar resultado
B_release_wait:
    LDR r0, [r10]          @ Leer estado actual de KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BNE B_release_wait     @ Esperar aquí hasta que se suelte el pulsador de confirmación (==0)

@ **** Fase Resultado: Suma y visualización del resultado ****
    ADD r5, r2, r3         @ Calcular R = A + B y almacenar en R5 (resultado de 32 bits)

    @ Verificar overflow mediante la técnica de comprobar signos de operandos y resultado
    @ Caso 1: A positivo, B positivo, R negativo (overflow positivo a negativo)
    CMP r2, #0
    BLT check_negative_overflow  @ Si A < 0, no puede ser este caso
    CMP r3, #0
    BLT check_negative_overflow  @ Si B < 0, no puede ser este caso
    CMP r5, #0
    BLT overflow_case      @ Si R < 0 cuando A y B positivos, hay overflow
    B check_bounds         @ No hay overflow en este caso, verificar límites
    
check_negative_overflow:
    @ Caso 2: A negativo, B negativo, R positivo (overflow negativo a positivo)
    CMP r2, #0
    BGE check_bounds       @ Si A >= 0, no puede ser este caso
    CMP r3, #0
    BGE check_bounds       @ Si B >= 0, no puede ser este caso
    CMP r5, #0
    BGE overflow_case      @ Si R >= 0 cuando A y B negativos, hay overflow
    
check_bounds:
    @ Verificación adicional de límites
    CMP r5, #127           @ Comparar resultado con 127 (máximo 8-bit)
    BGT overflow_case      @ Si R5 > 127, overflow positivo
    CMP r5, #-128          @ Comparar resultado con -128 (mínimo 8-bit)
    BLT overflow_case      @ Si R5 < -128, overflow negativo

    @ ** Caso sin overflow: mostrar resultado normalmente **
    MOV r0, #0x50          @ Cargar en r0 el patrón 0x50 que representa la letra 'r' (resultado) en 7 segmentos
    STR r0, [r11]          @ Mostrar 'r' en el display de 7 segmentos HEX0
    
    @ Extraer los 8 bits menos significativos del resultado para mostrar en LEDs
    AND r0, r5, #0xFF      @ Obtener solo los 8 bits menos significativos del resultado
    STR r0, [r8]           @ Escribir los 8 bits de resultado en los LEDs
    
    @ Esperar confirmación de visualización antes de reiniciar ciclo
result_wait:
    LDR r0, [r10]          @ Leer estado actual de KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BEQ result_wait        @ Si KEY0 no está presionado, seguir esperando
    
    @ Esperar liberación del botón antes de reiniciar
result_release_wait:
    LDR r0, [r10]          @ Leer estado actual de KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BNE result_release_wait@ Esperar aquí hasta que se suelte el pulsador
    
    B stageA               @ Reiniciar el ciclo para permitir ingresar nuevos operandos

overflow_case:
    @ ** Caso de overflow: indicar error **
    MOV r0, #0x71          @ Cargar en r0 el patrón 0x71 que representa la letra 'F' (overflow) en 7 segmentos
    STR r0, [r11]          @ Mostrar 'F' en el display de 7 segmentos para indicar overflow
    MOV r0, #0x00          @ Preparar valor 0x00 para apagar todos los LEDs
    STR r0, [r8]           @ Apagar los LEDs (ningún bit encendido) debido a overflow
    
    @ Esperar confirmación antes de reiniciar ciclo
overflow_wait:
    LDR r0, [r10]          @ Leer estado actual de KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BEQ overflow_wait      @ Si KEY0 no está presionado, seguir esperando
    
    @ Esperar liberación del botón antes de reiniciar
overflow_release_wait:
    LDR r0, [r10]          @ Leer estado actual de KEY0
    ANDS r0, r0, #0x1      @ Aislar bit0 y actualizar flags
    BNE overflow_release_wait @ Esperar aquí hasta que se suelte el pulsador
    
    B stageA               @ Reiniciar el ciclo para permitir ingresar nuevos operandos
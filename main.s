
    ; Archivo:	    main.s
    ; Proyecto:	    Laboratorio_05 (Displays simultáneos)
    ; Dispositivo:  PIC16F887
    ; Autor:	    Pablo Caal
    ; Compilador:   pic-as (v2.30), MPLABX V5.40
    ;
    ; Programa:	Contador de 8-bits empleando botones (binario y hexadecimal)
    ; Hardware:	Push botons en el Puerto B
    ;		Led's de contador en Puerto C
    ;		Salidas para displays simultáneos en Puerto D
    ;
    ; Creado: 21 feb, 2022
    ; Última modificación: 21 feb, 2022
    
    PROCESSOR 16F887
    #include <xc.inc>

    ; CONFIG1
	CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
	CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
	CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
	CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
	CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
	CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)

	CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
	CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
	CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
	CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

    ; CONFIG2
	CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
	CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

    ;------------------------------ MACROS -------------------------------------
    RESET_TIMER MACRO VALOR_TIMER
	BANKSEL TMR0		; Direccionamos a banco correcto
	MOVLW   VALOR_TIMER	; Cargamos a W el valor a configurar
	MOVWF   TMR0		; Enviamos a TMR0 el valor para configurar el tiempo de retardo
	BCF	T0IF		; Limpiamos la bandera de interrupción
	endm

    ;------------------------- VALORES EN MEMORIA ------------------------------
    ; Definición de valores constantes (Correspondiente a los botones del puerto B)
	B_INC	    EQU 0	; Valor constante equivalente
	B_DEC	    EQU 1	; Valor constante equivalente 
	
    ; Status de las interrupciones
    PSECT udata_shr		; Memoria compartida
	W_TEMP:		DS 1	; 1 byte
	STATUS_TEMP:	DS 1	; 1 byte
    
    ; Variables globales
	PSECT udata_bank0	; Memoria común
	CONTADOR:	DS 1	; Variable que almacena el valor actual del contador
	BANDERA:	DS 1	; Bandera indicadora del display a utilizar
	NIBBLES:	DS 2	; Variable que almacena de forma independiente los nibbles de CONTADOR
	DISPLAY:	DS 2	; Variable con el valor codificado correspondiente a cada display
      
    ;-------------------------- VECTOR RESET -----------------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h			; Posición 0000h para el reset
    resetVec:
        PAGESEL main		; Cambio de pagina
        GOTO    main

    ;-------------------- SUBRUTINAS DE INTERRUPCION ---------------------------
    ORG 04h			; Posición 0004h para las interrupciones
    PUSH:			
	MOVWF   W_TEMP		; Guardamos en W el valor de la variable W_TEMP
	SWAPF   STATUS, W	; Hacemos swap de nibbles y guardamos en W
	MOVWF   STATUS_TEMP	; Almacenamos W en variable STATUS_TEMP
	
    ISR:			; Verificación de banderas de las interrupciones
	BTFSC   RBIF		; Vericamos si hay interrupción de cambio en el puerto B
	CALL    INT_B		; Subrutina INT_B
	
	BTFSC	T0IF		; Verificamos si hay interrupción del TIMER0
	CALL	INT_TMR0	; Subrutina INT_TMR0
	
    POP:				
	SWAPF   STATUS_TEMP, W	; Hacemos swap de nibbles y guardamos en W
	MOVWF   STATUS		; Trasladamos W al registro STATUS
	SWAPF   W_TEMP, F	; Hacemos swap de nibbles y guardamos en W_TEMP 
	SWAPF   W_TEMP, W	; Hacemos swap de nibbles y guardamos en W
	RETFIE
    
    ;------------------------ RUTINAS PRINCIPALES ------------------------------
    PSECT code, delta=2, abs
    ORG 100h	; posición 100h para el codigo
    
    main:
	CALL	CONFIG_IO	    ; Comfiguración de los puertos	
	CALL	CONFIG_CLK	    ; Configuración del osciloscopio
	CALL	CONIFG_INTERRUPT    ; Configuracion de interrupciones
	CALL	CONFIG_IOCB	    ; Configuración de IOCB
	CALL	CONFIG_TIMER0	    ; Configuración de TMR0
	BANKSEL PORTA		; Direccionamiento a banco 00
	
    loop:			; Rutina que se estará ejecutando indefinidamente
	MOVF    PORTA, W	; Colocar el valor del contador en el registro W
	MOVWF   CONTADOR	; Colocar el valor actual del registro W en la variable CONTADOR
	CALL	OBTENER_VALOR	; Subrutina para obtener el valor actual del contador
	CALL	PREPARAR_VALOR	; Subrutina para colocar el valor del contador en los displays
	GOTO	loop		; Volvemos a comenzar con el loop
	
    ;--------------------------- SUBRUTINAS VARIAS -----------------------------
    OBTENER_VALOR:
	MOVLW   0x0F		; Colocar el valor 0x0F en registro W
	ANDWF   CONTADOR, W	; Hacer un AND de 0xF con la variable CONTADOR
	MOVWF   NIBBLES		; Almacenar el valor de W en variable NIBBLES posición 0
	
	MOVLW   0xF0		; Colocar el valor 0xF0 en registro W
	ANDWF   CONTADOR, W	; Hacer un AND de 0xF con la variable CONTADOR
	MOVWF   NIBBLES+1	; Almacenar el valor de W en variable NIBBLES posición 1
	SWAPF   NIBBLES+1, F	; Hacer un SWAP de nibbles de la variable NIBBLES posición 1
	return	
	
    PREPARAR_VALOR:
	MOVF    NIBBLES, W	; Colocamos el valor de NIBBLES (posición 0) en W
	CALL    TABLA		; Transformamos el valor a enviar a display
	MOVWF   DISPLAY		; Guardamos en variable DISPLAY

	MOVF    NIBBLES+1, W	; Colocamos el valor de NIBBLES (posición 1) en W
	CALL    TABLA		; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+1	; Guardamos en variable DISPLAY
	return

    COLOCAR_VALOR:
	BCF	PORTE, 0	; Apagamos display de nibble alto
	BCF	PORTE, 1	; Apagamos display de nibble bajo
	BTFSC   BANDERA, 0	; Verificamos bandera
	GOTO    DISPLAY_1	;  

	DISPLAY_0:			
	    MOVF    DISPLAY, W	    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTE, 1	    ; Activamos el primer display
	    BSF	    BANDERA, 0	    ; Alternamos el valor de la BANDERA para el siguiente ciclo
	return

	DISPLAY_1:
	    MOVF    DISPLAY+1, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTE, 0	    ; Activamos el segundo display
	    BCF	    BANDERA, 0	    ; Alternamos el valor de la BANDERA para el siguiente ciclo
	return
    
    INT_B:
	BANKSEL PORTB
	BTFSS   PORTB, B_INC	; Verificar si el bit 0 del puerto B está presionado
	INCF    PORTA		; Incrementar contador 
	BTFSS   PORTB, B_DEC	; Verificar si el bit 1 del puerto B no está presionado
	DECF    PORTA		; Decrementar contador
	BCF	RBIF		; Limpiar la bandera de cambio del PORTB
	return  
	
    INT_TMR0:
	RESET_TIMER 61		; Ingresamos a Macro con valor 61 para configurar retardo de 50ms
	CALL	COLOCAR_VALOR	; Llamamos a subrutina para colocar valores en displays
	return

    ;--------------------- SUBRUTINAS DE CONFIGURACIÓN -------------------------
    CONFIG_TIMER0:
	BANKSEL OPTION_REG	; Redireccionamos de banco
	BCF	T0CS		; Configuramos al timer0 como temporizador
	BCF	PSA		; Configurar el Prescaler para el timer0 (No para el Wathcdog timer)
	BSF	PS2
	BSF	PS1
	BCF	PS0		; PS<2:0> -> 110 (Prescaler 1:128)
	RESET_TIMER 61		; Reiniciamos la bandera interrupción
	return
    
    CONFIG_CLK:			; Rutina de configuración de oscilador
	BANKSEL OSCCON	    
	BSF	OSCCON, 0
	BCF	OSCCON, 4
	BSF	OSCCON, 5
	BSF	OSCCON, 6	; Oscilador con reloj de 4 MHz
	return
	
    ; VERIFICAR UTILIDAD DE SIGUIENTE SUBRUTINA:
    CONFIG_IOCB:
	BANKSEL TRISB
	BSF	IOCB, B_INC	; Habilitar el registro IOCB para el primer bit
	BSF	IOCB, B_DEC	; Habilitar el registro IOCB para el segundo bit
	
	BANKSEL PORTB
	MOVF    PORTB, W	; Mover el valor del puerto B al registro W
	BCF	RBIF		; Limpieza de la bandera de interrupción por cambio RBIF
	return

    CONIFG_INTERRUPT:
	BANKSEL INTCON
	BSF	GIE		; Habilitamos a todas las interrupciones
	BSF	RBIE		; Habilitamos las interrupciones por cambio de estado del PORTB
	BCF	RBIF		; Limpieza de la bandera de la interrupción de cambio
	BSF	T0IE		; Habilitamos la interrupción del TMR0
	BCF	T0IF		; Limpieza de la bandera de TMR0
	return
	
    CONFIG_IO:
	BANKSEL ANSEL		; Direccionamos de banco
	CLRF    ANSEL		; Configurar como digitales
	CLRF    ANSELH		; Configurar como digitales
	
	BANKSEL TRISA		; Direccionamos de banco
	BSF	TRISB, 0	; Habilitamos como entrada al bit 0 de PORTB
	BSF	TRISB, 1	; Habilitamos como entrada al bit 1 de PORTB 
	BCF	TRISB, 2	; Habilitamos al resto del PORTB como entradas
	BCF	TRISB, 3
	BCF	TRISB, 4
	BCF	TRISB, 5
	BCF	TRISB, 6
	BCF	TRISB, 7
	CLRF	TRISA		; Habilitamos al PORTA como salida
	CLRF	TRISC		; Habilitamos al PORTA como salida
	BCF	TRISE, 0	; Habilitamos como salidas los 2 lsf del PORTE
	BCF	TRISE, 1
	
	BCF	OPTION_REG, 7   ; Habilitar las resistencias pull-up (RPBU)
	BSF	WPUB, B_INC	; Habilita el registro de pull-up en RB0 
	BSF	WPUB, B_DEC	; Habilita el registro de pull-up en RB1

	BANKSEL PORTA		; Direccionar de banco
	CLRF    PORTA		; Limpieza de PORTA
	CLRF    PORTB		; Limpieza de PORTB
	CLRF	PORTC		; Limpieza de PORTC
	CLRF	PORTE		; Limpieza de PORTE
	CLRF	BANDERA
	return
	
    ;------------------------ TABLA  HEXADECIMAL -------------------------------
    ORG 200h
    TABLA:
	CLRF    PCLATH		; Limpiamos registro PCLATH
	BSF	PCLATH, 1	; Posicionamos el PC en dirección 02xxh
	ANDLW   0x0F		; no saltar más del tamaño de la tabla
	ADDWF   PCL		; Apuntamos el PC a caracter en ASCII de CONT
	RETLW   00111111B	; 0
	RETLW   00000110B	; 1
	RETLW   01011011B	; 2
	RETLW   01001111B	; 3
	RETLW   01100110B	; 4
	RETLW   01101101B	; 5
	RETLW   01111101B	; 6
	RETLW   00000111B	; 7
	RETLW   01111111B	; 8
	RETLW   01101111B	; 9
	RETLW   01110111B	; A
	RETLW   01111100B	; b
	RETLW   00111001B	; C
	RETLW   01011110B	; d
	RETLW   01111001B	; E
	RETLW   01110001B	; F
    END



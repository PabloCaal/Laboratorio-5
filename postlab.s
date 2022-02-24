
    ; Archivo:	    postlab.s
    ; Proyecto:	    Laboratorio_05 (Displays simult�neos)
    ; Dispositivo:  PIC16F887
    ; Autor:	    Pablo Caal
    ; Compilador:   pic-as (v2.30), MPLABX V5.40
    ;
    ; Programa:	Contador de 8-bits empleando botones (binario y hexadecimal)
    ; Hardware:	Push botons en el Puerto B
    ;		Led's de contador en Puerto C
    ;		Salidas para displays simult�neos en Puerto D
    ;
    ; Creado: 21 feb, 2022
    ; �ltima modificaci�n: 21 feb, 2022
    
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
	BCF	T0IF		; Limpiamos la bandera de interrupci�n
	endm

    ;------------------------- VALORES EN MEMORIA ------------------------------
    ; Definici�n de valores constantes (Correspondiente a los botones del puerto B)
	B_INC	    EQU 0	; Valor constante equivalente
	B_DEC	    EQU 1	; Valor constante equivalente 
	
    ; Status de las interrupciones
    PSECT udata_shr		; Memoria compartida
	W_TEMP:		DS 1	; 1 byte
	STATUS_TEMP:	DS 1	; 1 byte
    
    ; Variables globales
	PSECT udata_bank0	; Memoria com�n
	CONTADOR:	DS 1	; Variable que almacena el valor actual del contador hexadecimal
	BANDERA:	DS 1	; Bandera indicadora del display a utilizar para el contador hexadecimal
	NIBBLES:	DS 2	; Variable que almacena de forma independiente los nibbles de CONTADOR
	DISPLAY:	DS 2	; Variable con el valor codificado correspondiente a cada display del contador hexadecimal
    
	CONTADOR2:	DS 1	; Contador 2
	UNIDADES:	DS 1	; Variable que almacena las unidades del contador
	DECENAS:	DS 1	; Variable que almacena las decenas del contador
	CENTENAS:	DS 1	; Variable que almacena las centenas del contador
	DISPLAY2:	DS 3	; Variable con el valor codificado correspondiente a cada display del contador decimal
      
    ;-------------------------- VECTOR RESET -----------------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h			; Posici�n 0000h para el reset
    resetVec:
        PAGESEL main		; Cambio de pagina
        GOTO    main

    ;-------------------- SUBRUTINAS DE INTERRUPCION ---------------------------
    ORG 04h			; Posici�n 0004h para las interrupciones
    PUSH:			
	MOVWF   W_TEMP		; Guardamos en W el valor de la variable W_TEMP
	SWAPF   STATUS, W	; Hacemos swap de nibbles y guardamos en W
	MOVWF   STATUS_TEMP	; Almacenamos W en variable STATUS_TEMP
	
    ISR:			; Verificaci�n de banderas de las interrupciones
	BTFSC   RBIF		; Vericamos si hay interrupci�n de cambio en el puerto B
	CALL    INT_B		; Subrutina INT_B
	
	BTFSC	T0IF		; Verificamos si hay interrupci�n del TIMER0
	CALL	INT_TMR0	; Subrutina INT_TMR0
	
    POP:				
	SWAPF   STATUS_TEMP, W	; Hacemos swap de nibbles y guardamos en W
	MOVWF   STATUS		; Trasladamos W al registro STATUS
	SWAPF   W_TEMP, F	; Hacemos swap de nibbles y guardamos en W_TEMP 
	SWAPF   W_TEMP, W	; Hacemos swap de nibbles y guardamos en W
	RETFIE
    
    ;------------------------ RUTINAS PRINCIPALES ------------------------------
    PSECT code, delta=2, abs
    ORG 100h	; posici�n 100h para el codigo
    
    main:
	CALL	CONFIG_IO	    ; Comfiguraci�n de los puertos	
	CALL	CONFIG_CLK	    ; Configuraci�n del oscilador
	CALL	CONIFG_INTERRUPT    ; Configuracion de interrupciones
	CALL	CONFIG_IOCB	    ; Configuraci�n de IOCB
	CALL	CONFIG_TIMER0	    ; Configuraci�n de TMR0
	BANKSEL PORTA		    ; Direccionamiento a banco 00
	CLRF	CENTENAS
	CLRF	DECENAS
	CLRF	UNIDADES
	
    loop:			    ; Rutina que se estar� ejecutando indefinidamente
	MOVF    PORTA, W	    ; Colocar el valor del contador en el registro W
	MOVWF   CONTADOR	    ; Colocar el valor actual del registro W en la variable CONTADOR
	CALL	OBTENER_VALOR	    ; Subrutina para obtener el valor actual del contador
	CALL	PREPARAR_VALORES    ; Subrutina para colocar el valor del contador en los displays
	
	CLRF	CENTENAS
	CLRF	DECENAS
	CLRF	UNIDADES
		
	MOVF	CONTADOR, W	    ; Mover el valor del contador a W
	MOVWF	CONTADOR2	    ; Mover el valor de W al contador2
	CALL	CONTAR_CENTENAS
	CALL	CONTAR_DECENAS
	CALL	CONTAR_UNIDADES
	
	GOTO	loop		    ; Volvemos a comenzar con el loop
	
    ;--------------------------- SUBRUTINAS VARIAS -----------------------------
    INT_B:
	BANKSEL PORTB
	BTFSS   PORTB, B_INC	    ; Verificar si el bit 0 del puerto B est� presionado
	INCF    PORTA		    ; Incrementar contador 
	BTFSS   PORTB, B_DEC	    ; Verificar si el bit 1 del puerto B no est� presionado
	DECF    PORTA		    ; Decrementar contador
	BCF	RBIF		    ; Limpiar la bandera de cambio del PORTB
	return  
	
    INT_TMR0:
	RESET_TIMER 230		    ; Ingresamos a Macro con valor 230 para configurar retardo de 2ms
	CALL	COLOCAR_VALOR	    ; Llamamos a subrutina para colocar valores en displays
	return
	
    OBTENER_VALOR:
	MOVLW   0x0F		    ; Colocar el valor 0x0F en registro W
	ANDWF   CONTADOR, W	    ; Hacer un AND de 0xF con la variable CONTADOR
	MOVWF   NIBBLES		    ; Almacenar el valor de W en variable NIBBLES posici�n 0
	
	MOVLW   0xF0		    ; Colocar el valor 0xF0 en registro W
	ANDWF   CONTADOR, W	    ; Hacer un AND de 0xF con la variable CONTADOR
	MOVWF   NIBBLES+1	    ; Almacenar el valor de W en variable NIBBLES posici�n 1
	SWAPF   NIBBLES+1, F	    ; Hacer un SWAP de nibbles de la variable NIBBLES posici�n 1
	return	
	
    PREPARAR_VALORES:
	MOVF    NIBBLES, W	    ; Colocamos el valor de NIBBLES (posici�n 0) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY		    ; Guardamos en variable DISPLAY

	MOVF    NIBBLES+1, W	    ; Colocamos el valor de NIBBLES (posici�n 1) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+1	    ; Guardamos en variable DISPLAY+1
	
	MOVF    UNIDADES, W	    ; Colocamos el valor de NIBBLES (posici�n 0) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY2	    ; Guardamos en variable DISPLAY2
	
	MOVF    DECENAS, W	    ; Colocamos el valor de NIBBLES (posici�n 1 en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY2+1	    ; Guardamos en variable DISPLAY2+1
	
	MOVF    CENTENAS, W	    ; Colocamos el valor de NIBBLES (posici�n 2) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY2+2	    ; Guardamos en variable DISPLAY2+2
	return

    COLOCAR_VALOR:
	BCF	PORTD, 0	    ; Apagamos display de nibble alto
	BCF	PORTD, 1	    ; Apagamos display de nibble bajo
	BCF	PORTD, 2	    ; Apagamos display de UNIDADES
	BCF	PORTD, 3	    ; Apagamos display de DECENAS
	BCF	PORTD, 4	    ; Apagamos display de CENTENAS
	
	; L�gica de condicionales para verificar que display encender cada 5 ms
	BTFSC   BANDERA, 4	    ; Verificamos bandera 4
	GOTO    DISPLAY_4
	BTFSC   BANDERA, 3	    ; Verificamos bandera 3
	GOTO    DISPLAY_3
	BTFSC   BANDERA, 2	    ; Verificamos bandera 2
	GOTO    DISPLAY_2
	BTFSC   BANDERA, 1	    ; Verificamos bandera 1
	GOTO    DISPLAY_1
	BTFSC   BANDERA, 0	    ; Verificamos bandera 0
	GOTO    DISPLAY_0
	
	DISPLAY_0:			
	    MOVF    DISPLAY, W	    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTD, 1	    ; Activamos el primer display
	    BCF	    BANDERA, 0	    ;
	    BSF	    BANDERA, 1	    ;
	return

	DISPLAY_1:
	    MOVF    DISPLAY+1, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTD, 0	    ; Activamos el segundo display
	    BCF	    BANDERA, 1	    ;
	    BSF	    BANDERA, 2	    ;
	return
	
	DISPLAY_2:			
	    MOVF    DISPLAY2, W	    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 4	    ; Activamos el primer display
	    BCF	    BANDERA, 2	    
	    BSF	    BANDERA, 3	    
	return

	DISPLAY_3:
	    MOVF    DISPLAY2+1, W   ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 3	    ; Activamos el segundo display
	    BCF	    BANDERA, 3	    
	    BSF	    BANDERA, 4	    
	return
	
	DISPLAY_4:
	    MOVF    DISPLAY2+2, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 2	    ; Activamos el display de centenas
	    BCF	    BANDERA, 4	    
	    BSF	    BANDERA, 0	    
	return
	    
    CONTAR_CENTENAS:
	MOVLW	100		    ; Colocar el valor de 100 en W
	SUBWF	CONTADOR2, F	    ; Restar 100 a contador 2 y guardar en contador 2
	INCF	CENTENAS
	BTFSC	STATUS, 0	    ; Verificar si ocurri� BORROW
	GOTO	$-4
	DECF	CENTENAS
	MOVLW	100		    ; Colocar el valor de 100 en 
	ADDWF	CONTADOR2, F
	return  
	
    CONTAR_DECENAS:
	MOVLW	10		    ; Colocar el valor de 100 en W
	SUBWF	CONTADOR2, F	    ; Restar 10 a contador 2 y guardar en contador 2
	INCF	DECENAS
	BTFSC	STATUS, 0	    ; Verificar si ocurri� BORROW
	GOTO	$-4
	DECF	DECENAS
	MOVLW	10		    ; Colocar el valor de 100 en 
	ADDWF	CONTADOR2, F
	return  
	
    CONTAR_UNIDADES:
	MOVLW	1		    ; Colocar el valor de 100 en W
	SUBWF	CONTADOR2, F	    ; Restar 1 a contador 2 y guardar en contador 2
	INCF	UNIDADES
	BTFSC	STATUS, 0	    ; Verificar si ocurri� BORROW
	GOTO	$-4
	DECF	UNIDADES
	MOVLW	1		    ; Colocar el valor de 100 en 
	ADDWF	CONTADOR2, F
	return
	    
    ;--------------------- SUBRUTINAS DE CONFIGURACI�N -------------------------
    CONFIG_TIMER0:
	BANKSEL OPTION_REG	; Redireccionamos de banco
	BCF	T0CS		; Configuramos al timer0 como temporizador
	BCF	PSA		; Configurar el Prescaler para el timer0 (No para el Wathcdog timer)
	BSF	PS2
	BSF	PS1
	BCF	PS0		; PS<2:0> -> 110 (Prescaler 1:128)
	RESET_TIMER 240		; Reiniciamos la bandera interrupci�n
	return
    
    CONFIG_CLK:			; Rutina de configuraci�n de oscilador
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
	BCF	RBIF		; Limpieza de la bandera de interrupci�n por cambio RBIF
	return

    CONIFG_INTERRUPT:
	BANKSEL INTCON
	BSF	GIE		; Habilitamos a todas las interrupciones
	BSF	RBIE		; Habilitamos las interrupciones por cambio de estado del PORTB
	BCF	RBIF		; Limpieza de la bandera de la interrupci�n de cambio
	BSF	T0IE		; Habilitamos la interrupci�n del TMR0
	BCF	T0IF		; Limpieza de la bandera de TMR0
	return
	
    CONFIG_IO:
	BANKSEL ANSEL		; Direccionamos de banco
	CLRF    ANSEL		; Configurar como digitales
	CLRF    ANSELH		; Configurar como digitales
	
	BANKSEL TRISA		; Direccionamos de banco
	BSF	TRISB, 0	; Habilitamos como entrada al bit 0 de PORTB
	BSF	TRISB, 1	; Habilitamos como entrada al bit 1 de PORTB 
	BCF	TRISB, 2	; Habilitamos al resto del PORTB como salidas
	BCF	TRISB, 3
	BCF	TRISB, 4
	BCF	TRISB, 5	
	BCF	TRISB, 6
	BCF	TRISB, 7
	CLRF	TRISA		; Habilitamos al PORTA como salida
	CLRF	TRISC		; Habilitamos al PORTC como salida
	CLRF	TRISD		; Habilitamos al PORTD como salida
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
	CLRF	PORTD		; Limpieza de PORTD
	CLRF	BANDERA
	return
	
    ;------------------------ TABLA  HEXADECIMAL -------------------------------
    ORG 200h
    TABLA:
	CLRF    PCLATH		; Limpiamos registro PCLATH
	BSF	PCLATH, 1	; Posicionamos el PC en direcci�n 02xxh
	ANDLW   0x0F		; no saltar m�s del tama�o de la tabla
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
# language: es

Característica: Una función para validar cadenas de caracteres llamada MiValidator

    Sólo una descripción de la característica
    La segunda línea

    @Mockery
    Escenario: Algo usa MiValidator

        Sólo una descripción del escenario
        La segunda línea

        Dado MiValidator finge devolver True
        Cuando alguien llama algo que usa MiValidator
        Entonces MiValidator fue llamado una vez

    @Examples
    Esquema del escenario: MiValidator debería devolver 'true' sólo para palabras que empiecen con s minúscula
        Cuando MiValidator se llama con <palabra>
        Entonces MiValidator debería devolver a <Valor de verdad>

        @Example1
        Ejemplos: Algunas s palabras con los resultados esperados
            | palabra | Valor de verdad |
            | sandy   | True            |
            | sears   | True            |

        @Example2
        Ejemplos: Algunas otras palabras que van a fallar
            | palabra | Valor de verdad |
            | Super   | False           |
            | Breath  | False           |
            | test    | False           |

# language: de

Funktionalität: Eine Zeichenkettenprüfungsfunktion namens MeinValidator

    Nur eine Beschreibung der Funktionalität
    Die zweite Zeile

    @Mockery
    Szenario: Etwas verwendet MeinValidator

        Nur eine Beschreibung des Szenarios
        Die zweite Zeile

        Angenommen MeinValidator gibt vor, True zurückzugeben
        Wenn jemand etwas aufruft, das MeinValidator benutzt
        Dann wurde MeinValidator einmal aufgerufen

    @Examples
    Szenariogrundriss: MeinValidator sollte nur 'true' für Wörter mit einem kleinen s zurückgeben
        Wenn MeinValidator mit <Wort> aufgerufen wird
        Dann sollte MeinValidator <Wahrheitswert> zurückgeben

        @Example1
        Beispiele: Einige Wörter mit s und den zu erwartenden Ergebnissen
            | Wort   | Wahrheitswert |
            | spitze | True          |
            | schön  | True          |

        @Example2
        Beispiele: Einige andere Wörter, die alle fehlschlagen werden
            | Wort   | Wahrheitswert |
            | Super  | False         |
            | Atem   | False         |
            | test   | False         |

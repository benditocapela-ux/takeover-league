# WebKit-Pixelvergleich: Snapshot-Flush

Beim direkten synchronen `getImageData` unmittelbar nach `drawImage` meldete WebKit in der integrierten Variantenprüfung eine Abweichung (beispielsweise maximal 237, mittlere Kanalabweichung 0,29745). Die unmittelbar danach exportierten PNGs derselben beiden Canvases waren bei unabhängigem Dekodieren über `@napi-rs/canvas` vollständig pixelidentisch (0 unterschiedliche Pixel).

Die Paritätsprüfung erzwingt deshalb vor dem unverändert exakten RGBA-Vergleich einen PNG-Snapshot beider Canvases. Das synchronisiert die beobachtbare Ausgabe. Es werden weder Toleranzen erhöht noch Pixelbereiche ausgeschlossen. Dieser Flush gilt nur für den visuellen Paritätsvergleich; die gesonderten Kalt-/Warm-Benchmarks behalten ihre bisherige Readback-Methode.

Zusätzlich werden temporäre Vergleichs- und UI-Canvases nach dem Kopieren explizit freigegeben. Dies begrenzt native Grafikpuffer bei vielen Auswahlwechseln, unabhängig vom Zeitpunkt der JavaScript-Speicherbereinigung.

Die vorläufige Vermutung sichtbar verschwundener Artwork-Ebenen ist durch diesen identischen PNG-Vergleich nicht bestätigt. Die endgültige Freigabe der technischen Varianten hängt weiterhin vom vollständigen Chromium-/WebKit-Test und unveränderten Quell-Hashes ab; künstlerische Freigabe ist damit nicht verbunden.

Archivierte Beweisbilder: [beobachtet](evidence/webkit-readback-observed.png) und [Referenz](evidence/webkit-readback-reference.png). Beide PNG-Dateien haben denselben SHA-256: `87126e3faac1b0984bea37edcce6df927ccd63d30bc6bca8257726ec8b031761`.

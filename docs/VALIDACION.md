# Validación · 18 de octubre de 2026

- `swift test --package-path TiskzCore`: **13 pruebas, 0 fallos**. Incluyen tipos JSON estrictos, aislamiento de Scribe, revisiones, finales inmutables, autorización de corte ligada a sesión, caducidad de captura y conversión PCM real de 48 kHz a mono 16 kHz.
- `xcodebuild test`: **3 pruebas UI aprobadas, 0 fallos** en **iPhone-17-Test / iOS 26.1**; navegación, consentimientos, configuración, historial, contactos y teclado sin efectuar llamadas.
- `xcodebuild build -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO`: compilación **Release para iPhone arm64** aprobada, objetivo mínimo **iOS 17.0**. No equivale a probar el runtime iOS 17; en esta Mac solo estaba disponible el simulador iOS 26.1.
- Catálogo de recursos comprobado en el bundle: escudo de marca, icono del lanzador y 27 vectores Tabler. La paleta sRGB coincide con `Theme.kt` de Android.
- Se compararon capturas de Android `13f8908` y iOS a tamaño lógico (411 × 914 dp y 402 × 874 pt): [inicio Android](home-android-api36.png), [inicio iOS](home-ios26.png), [permiso de contactos Android](contacts-android-api36.png), [contactos iOS](contacts-ios26.png) y [marcador iOS](dialer-ios26.png). Cabecera, hero, estadísticas, tarjetas, permisos y teclado conservan el orden, paleta, Roboto y proporciones; la barra de estado, Dynamic Island y algunos controles nativos siguen siendo propios de iOS. Las capturas no contienen claves ni conversaciones reales.

No había identidad de firma Apple ni un iPhone de pruebas disponible en esta sesión. No se publicó una IPA ni se validó una conversación real con marin desde un iPhone. Las pruebas automáticas no consumen llamadas de Vapi ni créditos de IA. Para esa validación, sigue el inicio rápido del README y prueba con audio autorizado.

El repositorio documenta por separado las funciones implementadas y las restricciones de iOS: no automatiza las llamadas de la SIM y no promete alertas remotas cuando la app está suspendida. La comparación de voces entre llamadas depende de un servicio de embeddings que el backend aún no tiene.

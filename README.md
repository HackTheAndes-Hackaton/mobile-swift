# Tiskz · iOS

Aplicación nativa en Swift y SwiftUI para **iOS 17 o posterior**, separada del cliente Android. Usa el mismo servidor de Maritime y no lleva claves de Vapi, OpenAI ni ElevenLabs dentro de la app.

## Abrir y ejecutar

1. Clona este repositorio y abre `Tiskz.xcodeproj` en Xcode. Se resuelven `TiskzCore` (local) y WebRTC **155.0.0** (versión fija).
2. Selecciona el esquema **Tiskz** y un simulador o tu iPhone.
3. Para un iPhone: conecta por USB, activa el modo de desarrollador en el dispositivo y selecciona tu **Team** en Signing & Capabilities. Cambia el bundle identifier si tu cuenta lo requiere. Ejecuta con ▶︎ y confía en la firma si iOS lo solicita. Una cuenta personal permite probar con las restricciones de Apple; TestFlight requiere distribución firmada.
4. Completa la bienvenida o elige **Probar sin activar**. En **Ajustes** de Tiskz, guarda el canal HTTPS y el **código privado del equipo**. Se guarda en Keychain. No introduzcas una clave de Vapi en este campo.
5. En **Voz**, selecciona **Conversar con marin**, autoriza el análisis y conecta. Permite el micrófono cuando iOS pregunte. El otro modo de micrófono transcribe y analiza sin voz de respuesta.
6. Para evidencia: antes de conectar, autoriza por separado conservar fragmentos. Habla al menos un segundo. Puedes guardar los últimos 10 s y escucharlos durante la sesión; el micrófono se silencia durante la reproducción. El servidor también puede solicitar ese fragmento al detectar riesgo. La pantalla confirma el resultado real del guardado.

El canal del equipo ya está preconfigurado: `https://api.maritime.sh/a/ebf0eb81-42c0-4437-a044-1af84af1b755`. El código privado se comparte por un canal privado, nunca por Git.

## Qué incluye

La interfaz copia la marca de la APK: tema claro, paleta azul, logo, tarjetas, barra de riesgo, burbujas, bienvenida e inicio. Consulta [colores y componentes](docs/DISENO_IOS.md).


- WebRTC nativo de audio: GPT-Live 1 y voz **marin**, con señalización y credenciales efímeras gestionadas por Maritime.
- Análisis del micrófono con commits tras pausas de 1,2 s; no corta palabras por un temporizador fijo.
- Transcripciones, comprensión y estados **observar / verificar / alertar / inconcluso** por WebSocket.
- Comparación de transcripción Scribe independiente de la decisión principal, cuando el servidor la emite.
- Búfer PCM en RAM limitado a 10 s, guardado idempotente y reproducción de evidencia autorizada. Una captura de micrófono no captura el audio de una llamada de la SIM.
- Historial local protegido, **apagado por defecto**. Envío manual al panel mediante `PUT /calls/{id}`, con autorización separada y API key en Keychain.
- Contactos con búsqueda y permiso separado; teclado que abre llamadas en Teléfono, y editor nativo para agregar contactos. La agenda no se envía al servidor.
- Avisos locales con permiso del usuario. No hay integración APNs en este repositorio ni recepción remota garantizada con la app suspendida.

## Llamadas de operadora: diferencia con Android

**iOS no permite que esta app conteste, llame a Vapi, una la conferencia y cuelgue los participantes de una llamada de la SIM automáticamente.** CallKit integra llamadas VoIP propias; no entrega el audio de Teléfono ni ese control sobre la SIM. Apple lo aclara en [su respuesta técnica](https://developer.apple.com/forums/thread/835552) y [sobre acceso a audio de otras llamadas](https://developer.apple.com/forums/thread/841340).

Para probar una llamada normal con la infraestructura actual:

1. Confirma con la operadora los costos del destino Vapi y la conferencia.
2. Contesta en **Teléfono**, agrega manualmente el número de Vapi y pulsa **Unir** si tu línea lo permite.
3. Vuelve a Tiskz, elige **Ver llamada Vapi**, autoriza el análisis y conecta. Es un **observador**, no toma el control de corte que usa Android.
4. Mantén Tiskz en primer plano para ver transcripciones y alertas. Al colgar Vapi, la app no afirma haber terminado los otros participantes; finaliza la conferencia desde Teléfono.

Al ir al fondo/bloquear el iPhone se cierra la conexión y se libera el micrófono. Para una experiencia de llamadas por internet en segundo plano se necesita completar CallKit/PushKit y un backend de notificaciones VoIP; no se declaran modos de fondo que esta versión no implementa.

El reconocimiento de coincidencias de voz entre llamadas sigue pendiente del motor de embeddings del servidor. Guardar un WAV no implementa esa comparación ni acredita identidad.

## Desarrollo y validación

Herramientas usadas: Xcode 26.1.1, Swift 6.2.1 en modo Swift 5.9 y XcodeGen 2.46.0. Objetivo mínimo iOS 17. No se necesita CocoaPods.

```sh
swift test --package-path TiskzCore
# Solo si cambias project.yml; el proyecto generado está versionado:
brew install xcodegen
xcodegen generate
xcodebuild -project Tiskz.xcodeproj -scheme Tiskz \
  -destination 'platform=iOS Simulator,name=iPhone-17-Test' \
  -derivedDataPath DerivedData test CODE_SIGNING_ALLOWED=NO
```

Consulta [el contrato y las decisiones del port](docs/PORT_IOS.md). La compilación en simulador no sustituye una prueba de voz y conferencia en un iPhone real ni produce una IPA instalable sin firma.

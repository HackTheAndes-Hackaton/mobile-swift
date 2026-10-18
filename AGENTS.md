# Tiskz iOS

- Usa SwiftUI nativo, iOS 17+, y mantén el contrato actual de Maritime. No modifiques el backend como efecto lateral de un cambio de cliente.
- No prometas acceso o control de llamadas de SIM mediante CallKit, ni captura de audio de Teléfono. El canal Vapi es observador por defecto.
- Separa autorización de análisis, conservación de audio, historial local y envío al panel. Todos salvo el análisis solicitado están desactivados por defecto.
- No comitees secretos, transcripciones reales, grabaciones, perfiles de firma ni claves de Apple. Keychain para credenciales, nunca UserDefaults.
- Una alerta no confirma delito; una coincidencia de voz no confirma identidad. No produzcas embeddings ficticios ni marques como segura una sesión sin evaluación.
- Tras cambios de protocolo ejecuta `swift test --package-path TiskzCore`. Tras cambios de app compila para simulador; prueba UI si cambian navegación/consentimientos.
- `project.yml` es la fuente de configuración. Regenera `Tiskz.xcodeproj` con XcodeGen y comitea ambos. No versionar DerivedData ni binarios de WebRTC.

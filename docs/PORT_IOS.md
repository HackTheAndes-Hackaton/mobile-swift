# Contrato y límites del port

Base de referencia: Android `13f8908`, cliente 0.4.6, y protocolo de voz del repositorio `agents`. Este repositorio no modifica ni despliega ese servidor.

## Transporte

- HTTPS y WSS únicamente; se conserva el prefijo `/a/{agent}`. Se rechazan URLs con usuario, contraseña, query o fragmento, y no se siguen redirecciones con credenciales.
- `POST /v1/sessions`, cabecera `X-Voice-Token`, consentimiento explícito; assistant añade `mode=assistant` y `consentimiento_voz_ia=true`.
- `POST /v1/sessions/{id}/offer`: SDP local con ICE, respuesta SDP remota. Audio mono con VoiceProcessingIO y WebRTC; un único flujo alimenta RTP y el búfer consentido.
- `wss://…/ws/calls?session={id}&ticket={producer_token}`. Tras `session.ready` se envía `session.start`. Los eventos deben corresponder a la sesión activa; no se aplican eventos de otras llamadas.
- DataChannel `oai-events`: relay de eventos GPT-Live y contexto `session.thinking.append` con lista permitida y límites. El modo de transcripción envía finales inmutables y commits por silencio; el texto no ejecuta acciones.
- Revisión de análisis creciente; tipos booleanos estrictos y probabilidades finitas entre 0 y 1. Las revisiones nuevas invalidan orientaciones antiguas. Un error no significa “seguro”. Scribe tiene su propio estado y nunca cambia la decisión principal.
- `POST /v1/phone/monitor` usa `consentimiento_corte_automatico=false`; no solicita conservación de telefonía ni se hace pasar por un controlador de conferencia Android. El ticket abre `ws/calls?channel=phone&ticket=…`. Confirma recepción de alertas con `event.received`.
- Al finalizar se cierra el micrófono inmediatamente y se intenta `POST /v1/sessions/{id}/end`. Un fallo de red deja como último recurso la caducidad del servidor. WebSocket con ping de 20 s; desconexión de audio tolera 5 s antes de cerrar.

## Evidencia

Consentimiento separado. No se graba audio a disco en el iPhone. Búfer máximo de 10 s, salida PCM16 mono 16 kHz; mínimo de 1 s. El backend recibe `{request_id,audio_base64}` en `POST /v1/sessions/{id}/evidence`.

`audio.capture_requested` debe tener UUID de sesión/request, revisión válida, ventana de 10000 ms y caducidad futura de hasta 60 s; se confirma `audio.capture_received`. Se ignoran duplicados y se limita a tres solicitudes del servidor por sesión. `audio.capture_failed` informa ausencia de muestras/ocupación/fallo. Solo se muestra “guardado” tras respuesta con `clip_` válido o resultado del servidor correlacionado. El cliente no inventa embeddings ni inscribe identidades por similitud de voz.

La reproducción usa `GET /v1/sessions/{id}/evidence/{clip}` con ticket de productor, limita formato y tamaño y silencia el micrófono para evitar realimentación. No conserva el ticket dentro del historial.

## Datos y publicación

El código del equipo y la API key del panel se guardan con `WhenUnlockedThisDeviceOnly` en Keychain; no van a UserDefaults, logs o repositorio. El historial es opcional, limitado a 100 sesiones, con protección completa de archivos y excluido del backup. El usuario puede borrarlo. El envío al panel se inicia manualmente para cada sesión, con permiso separado; deja nulos los números y nombres que iOS no conoce. No declara una llamada “segura” por una probabilidad baja ni identifica a un estafador.

Antes de distribuir por App Store, completa la declaración de privacidad y sus finalidades según la configuración del servidor, revisa las licencias de WebRTC y prueba en dispositivo. Este prototipo no incluye APNs, PushKit, CallKit en segundo plano, extensión de bloqueo de números ni automatización de telefonía celular. No se incluye una firma de distribución.

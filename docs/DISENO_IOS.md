# Diseño de Tiskz en SwiftUI

Referencia visual: `HackTheAndes-Hackaton/mobile-repo`, **main `d63cbc1`**, consultado el 18 de octubre de 2026. Se portaron los tokens de `ui/theme/Theme.kt`, las formas de `ui/components/Common.kt` y las pantallas nativas. No se incrusta la web ni una captura de la APK.

## Paleta idéntica, sRGB

| Grupo | Valores hexadecimales |
| --- | --- |
| Marca | Navy `#0B1B4D`, Blue900 `#1E3A8A`, Blue700 `#1D4ED8`, Blue600 `#2563EB`, Sky `#38BDF8` |
| Superficies azules | Blue100 `#DBEAFE`, Blue50 `#EFF6FF` |
| Neutros | White `#FFFFFF`, Background `#F3F6FC`, Ink `#0F172A`, Muted `#64748B`, Line `#E2E8F0`, Surface `#F1F5F9` |
| Verde | `#10B981`, texto `#047857`, contenedor `#D1FAE5` |
| Ámbar | `#F59E0B`, texto `#B45309`, contenedor `#FEF3C7` |
| Naranja | `#F97316` |
| Rojo | `#E11D48`, texto `#9F1239`, contenedor `#FFE4E6` |
| Sombra | `#1E3A8A`, con opacidad suave |

La marca usa degradado Blue900 → Blue600 → Sky. Las burbujas del agente usan Blue700 → Blue600. Se conserva el tema claro de Android; no se sustituye por una paleta verde/negra.

## Componentes compartidos por las pantallas

| Android | SwiftUI |
| --- | --- |
| TiskzLogo / ic_tiskz_shield | `TiskzLogo` y `BrandShield`: mismo trazado vectorial y recortes de ondas |
| TiskzCard | `TiskzCard`: blanco, radio 24 pt (22/20 según variante), sombra azul |
| CallerAvatar | `CallerAvatar`: círculo azul claro, iniciales o persona; ignora emojis como inicial |
| StatusPill | `TiskzStatusPill` para estados de conexión y eventos |
| WaveBars | `TiskzWaveBars`, animación que respeta Reducir movimiento |
| RiskBar | `RiskBar`: porcentaje de 34 pt, barra de 12 pt y umbrales visuales 30/60/85 |
| AssessmentCard | `AssessmentCard`: observar azul, verificar ámbar, alertar rojo, inconcluso neutro |
| TranscriptBubble | `TranscriptBubble`: agente azul alineado a la derecha, interlocutor blanco a la izquierda, radios 22/6 pt |
| OnboardingScreen | `OnboardingView`: logo de 96 pt, tres ventajas, botón principal y acceso sin activar |
| ProtectionHero / StatsRow | `HomeView`: cabecera azul, esquinas inferiores de 36 pt, estadísticas superpuestas 44 pt y las tarjetas de llamadas, contactos y canal de voz en el orden Android |
| CallRecordRow / EmptyRecents | `CallRecordRow` y estado vacío, avatares y etiquetas de orientación |
| ContactsScreen / DialerScreen | `ContactsView`, `DialerView`: búsqueda, avatares, tarjetas y teclado; las llamadas se abren en Teléfono |
| SettingsScreen | `SettingsView`: tarjetas propias, campos delineados, switches azules y panel informativo con la misma paleta |

Los estilos están centralizados en `Tiskz/Views/DesignSystem.swift`. Los tokens de texto usan las medidas base de Android: cuerpo 17 pt, secundario 15 pt, nota 13 pt y título 22 pt. Se incluye la fuente variable Roboto que Android API 36 usa por defecto y se conserva Dynamic Type de iOS. Los símbolos de marca y los 27 íconos usados por la app se extrajeron como vectores de los recursos Android y del paquete Tabler de Compose; se compilan dentro de `Assets.xcassets`.

## Adaptaciones necesarias

La apariencia y las categorías de estadísticas siguen Android. Los resultados son orientativos y no identifican personas ni confirman delitos. Los textos de telefonía describen las capacidades reales de iOS: la tarjeta lleva a configurar el canal y la conferencia de la SIM sigue siendo manual.

Contactos requiere permiso independiente y permanece en el dispositivo; no se usa la agenda para atribuir identidades a voces. El alta usa el editor de Contactos de iOS. El historial muestra solo sesiones guardadas voluntariamente, no el registro de llamadas de la SIM, al que esta app no tiene acceso.

El icono de la app reproduce los vectores de `ic_launcher_background.xml` y `ic_launcher_foreground.xml`. Los assets vectoriales de la app se regeneran desde el checkout Android con `python3 scripts/extract_android_vectors.py`; el icono se regenera con `swift scripts/generate-icon.swift` en macOS; PNG de 1024 × 1024, sin canal alfa. La extracción necesita que exista el AAR Tabler Compose 1.1.1 en la caché Gradle local. Las capturas de referencia de Android API 36 (411 × 914 dp) e iPhone 17 (402 × 874 pt) están en [`home-android-api36.png`](home-android-api36.png) y [`home-ios26.png`](home-ios26.png). Los elementos de la barra de estado y la isla dinámica son propios de iOS y Android.

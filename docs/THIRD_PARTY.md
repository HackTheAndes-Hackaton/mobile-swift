# Dependencias

- **WebRTC 155.0.0**: distribución binaria de [stasel/WebRTC](https://github.com/stasel/WebRTC/tree/155.0.0), compilada del proyecto [WebRTC](https://webrtc.googlesource.com/src/). Código bajo licencia BSD de tres cláusulas y avisos de componentes adicionales; conserva los avisos de [LICENSE](https://webrtc.googlesource.com/src/+/refs/heads/main/LICENSE), [PATENTS](https://webrtc.googlesource.com/src/+/refs/heads/main/PATENTS) y las licencias incluidas en la distribución al redistribuir el SDK. El paquete fija versión, revisión y checksum del XCFramework.
- **Íconos vectoriales Tabler**: los 27 vectores de interfaz se extrajeron del artefacto `tabler-icons-android` 1.1.1, publicado por [Compose Icons](https://github.com/DevSrSouza/compose-icons), y conservan la licencia MIT de [Tabler Icons](https://github.com/tabler/tabler-icons). Los avisos están en [`licenses/compose-icons-MIT.txt`](../licenses/compose-icons-MIT.txt) y [`licenses/tabler-icons-MIT.txt`](../licenses/tabler-icons-MIT.txt).
- **Roboto variable**: archivo extraído del sistema Android API 36 usado como referencia visual; tipografía de [The Roboto Project](https://github.com/googlefonts/roboto-classic), bajo SIL Open Font License 1.1. El aviso está en [`licenses/Roboto-OFL.txt`](../licenses/Roboto-OFL.txt).
- **Marca Tiskz**: los vectores del escudo y del lanzador se derivan de los recursos XML del proyecto Android de Tiskz.
- **TiskzCore**: código de este repositorio; no usa un SDK de proveedor de IA. Las claves y las decisiones del modelo pertenecen al backend.

No se redistribuyen binarios de WebRTC en Git. Swift Package Manager descarga el artefacto durante la compilación.

import SwiftUI
import TiskzCore
import UserNotifications

private let accent = TiskzPalette.blue600
private enum AppDestination: Hashable { case voice, history, settings, contacts, dialer }
struct ContentView: View {
    @State private var path: [AppDestination] = []
    @AppStorage("onboarding-done") private var onboardingDone = false
    @State private var showOnboarding = false
    var body: some View {
        NavigationStack(path:$path) {
            HomeView(
                onOpenVoice:{ path.append(.voice) },
                onOpenHistory:{ path.append(.history) },
                onOpenSettings:{ path.append(.settings) },
                onOpenContacts:{ path.append(.contacts) },
                onOpenDialer:{ path.append(.dialer) },
            )
            .navigationDestination(for:AppDestination.self) { destination in
                Group {
                    switch destination {
                    case .voice: VoiceView()
                    case .history: HistoryView()
                    case .settings: SettingsView()
                    case .contacts: ContactsView(onOpenDialer:{ path.append(.dialer) })
                    case .dialer: DialerView()
                    }
                }.toolbar(.hidden,for:.navigationBar)
            }
        }
        .tint(accent).preferredColorScheme(path.isEmpty ? .dark : .light).font(TiskzType.body).foregroundStyle(TiskzPalette.ink)
            .onAppear { showOnboarding = !onboardingDone }
            .fullScreenCover(isPresented:$showOnboarding) {
                OnboardingView { prepare in onboardingDone = true; showOnboarding = false; if prepare { path.append(.settings) } }.interactiveDismissDisabled().preferredColorScheme(.light)
            }
    }
}
struct VoiceView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var session: CallSession
    @State private var mode: VoiceMode = .assistant
    @State private var consent = false
    @State private var evidence = false
    var body: some View {
        VStack(spacing:0) {
            TiskzTopBar(title:"Voz en vivo") { dismissVoice() }
            ScrollView {
                VStack(alignment:.leading, spacing:20) {
                    VStack(alignment:.leading,spacing:6) {
                        Text(mode == .phone ? "Llamadas telefónicas · alertas" : mode == .assistant ? "Conversar con Tiskz · marin" : "Micrófono → agentes → alerta").font(TiskzType.title)
                        Text("Analiza audio autorizado. La conexión se detiene al enviar la app al fondo.").font(TiskzType.small).foregroundStyle(TiskzPalette.muted)
                    }
                    if !session.active {
                        VStack(alignment:.leading, spacing:16) {
                            Text("Configura el canal").font(TiskzType.subtitle)
                            Picker("Canal", selection:$mode) { ForEach(VoiceMode.allCases) { Text($0.label).tag($0) } }.pickerStyle(.menu).accessibilityIdentifier("voice-mode")
                            Text(mode == .phone ? "Observa transcripciones y alertas de Vapi. Agrega el número a la conferencia desde Teléfono y vuelve aquí. iOS no permite unirla ni colgar la llamada de la SIM desde Tiskz." : mode == .assistant ? "Habla por internet con marin. Comprensión y detección se procesan en Maritime." : "El micrófono envía tu voz para transcripción y análisis; marin no responde en este modo.")
                                .font(TiskzType.small).foregroundStyle(TiskzPalette.muted)
                            VStack(alignment:.leading,spacing:6) {
                                Text("Canal HTTPS").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                                TextField("https://…",text:$settings.base).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().padding(12).overlay(RoundedRectangle(cornerRadius:12).stroke(TiskzPalette.line))
                                Text("Código privado del equipo").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).padding(.top,6)
                                SecureField("Código privado",text:$settings.code).textInputAutocapitalization(.never).autocorrectionDisabled().padding(12).overlay(RoundedRectangle(cornerRadius:12).stroke(TiskzPalette.line)).accessibilityIdentifier("voice-private-code")
                            }
                            Toggle("Autorizo analizar esta conversación", isOn:$consent).accessibilityIdentifier("analysis-consent")
                            if mode != .phone {
                                Toggle("Permitir conservar fragmentos de voz", isOn:$evidence)
                                Text("Con permiso, los últimos 10 segundos se conservan en memoria y pueden guardarse al detectar riesgo. Avisa a quienes participen. Una voz parecida no acredita identidad.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                            }
                            Button { session.start(settings:settings, mode:mode, consent:consent, evidence:evidence) } label: {
                                Label(mode == .phone ? "Conectar alertas" : "Conectar voz", systemImage:mode == .phone ? "antenna.radiowaves.left.and.right" : "mic.fill").frame(maxWidth:.infinity).padding(8)
                            }.buttonStyle(TiskzPrimaryButton()).disabled(!consent || settings.code.count < 12).accessibilityIdentifier("connect-voice")
                            if settings.code.count < 12 { Text("Introduce el código privado del equipo para conectar.").font(TiskzType.caption).foregroundStyle(TiskzPalette.amberDark) }
                        }.tiskzCard()
                    } else {
                        VStack(alignment:.leading, spacing:12) {
                            HStack(spacing:8) {
                                if session.connected && session.mode != .phone { TiskzWaveBars() }
                                TiskzStatusPill(text:session.message,pulsing:!session.connected)
                            }
                            HStack {
                                if session.mode != .phone { Button { session.toggleMute() } label: { Label(session.muted ? "Activar micrófono" : "Silenciar", systemImage:session.muted ? "mic.slash" : "mic") }.buttonStyle(.bordered) }
                                Button(role:.destructive) { session.stop() } label: { Label(session.mode == .phone ? "Desconectar" : "Finalizar", systemImage:"phone.down.fill") }.buttonStyle(.bordered)
                            }
                            if let ms = session.connectionMS { Text("Conexión: \(ms) ms").font(.caption.monospacedDigit()).foregroundStyle(TiskzPalette.muted) }
                            if let ms = session.deliveryMS { Text("Entrega de evento: ~\(ms) ms · depende del reloj del dispositivo").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted) }
                        }.tiskzCard()
                    }
                    if !session.active, !session.message.isEmpty { Text(session.message).foregroundStyle(TiskzPalette.muted) }
                    AnalysisView(analysis:session.analysis)
                    if session.active && session.mode != .phone && evidence {
                        VStack(alignment:.leading, spacing:10) {
                            Label("Evidencia de voz", systemImage:"waveform.path").font(TiskzType.subtitle)
                            Text(session.analysis.evidenceStatus).font(TiskzType.small)
                            HStack {
                                Button(session.evidenceBusy ? "Guardando…" : session.retryEvidence ? "Reintentar guardado" : "Guardar últimos 10 s") { session.saveManual() }.disabled(session.evidenceBusy || !session.connected)
                                if session.analysis.clipID != nil { Button(session.playing ? "Reproduciendo…" : "Escuchar") { session.playExcerpt() }.disabled(session.playing) }
                            }.buttonStyle(.bordered)
                            Text("El guardado no identifica a una persona. La comparación de voces entre llamadas requiere un motor adicional en el servidor.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                        }.tiskzCard()
                    }
                    VStack(alignment:.leading, spacing:8) {
                        Label("Mientras usas Tiskz", systemImage:"info.circle").font(TiskzType.subtitle)
                        Text("Mantén esta pantalla abierta. Al ir al fondo o bloquear el iPhone, Tiskz cierra el canal y el micrófono. Las notificaciones remotas requieren una integración APNs del servidor.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                    }.tiskzCard()
                }.padding()
            }.background(TiskzPalette.background)
                .onChange(of:mode) { _, _ in consent = false; evidence = false }
        }.background(TiskzPalette.background)
            .toolbar(.hidden,for:.navigationBar)
    }
    @Environment(\.dismiss) private var dismiss
    private func dismissVoice() { dismiss() }
}
struct AnalysisView: View {
    let analysis: Analysis
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            RiskBar(analysis:analysis)
            AssessmentCard(analysis:analysis)
            if analysis.readyToAnswer {
                TiskzStatusPill(text:"Ya puedes entrar · identidad no verificada",color:TiskzPalette.emeraldDark,container:TiskzPalette.emeraldContainer)
            }
            if let error = analysis.error { Label(error,systemImage:"exclamationmark.triangle").font(TiskzType.caption).foregroundStyle(TiskzPalette.redDark).padding(16).background(TiskzPalette.redContainer,in:RoundedRectangle(cornerRadius:20)) }
            Text("Conversación").font(TiskzType.subtitle)
            if analysis.captions.isEmpty { Text("Los fragmentos aparecerán al hablar. Los subtítulos pueden contener errores.").font(TiskzType.small).foregroundStyle(TiskzPalette.muted) }
            ForEach(analysis.captions) { TranscriptBubble(caption:$0) }
            if !analysis.summary.isEmpty {
                VStack(alignment:.leading,spacing:10) {
                    Text("Comprensión y evidencia").font(TiskzType.subtitle)
                    Text(analysis.summary).font(TiskzType.body)
                    if let a = analysis.currentAssessment {
                        ForEach(Array(a.quotes.enumerated()),id:\.offset) { _, quote in Text("“\(quote)”").font(TiskzType.small).foregroundStyle(TiskzPalette.muted) }
                    }
                }.tiskzCard()
            }
            if !analysis.comparison.isEmpty {
                DisclosureGroup("Scribe · comparación en vivo") {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Experimental · no controla el corte").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                        if let p = analysis.comparisonProbability { Text("Estimación paralela: \(Int(p * 100))%") }
                        ForEach(analysis.comparison) { Text(($0.final ? "Confirmado: " : "Provisional: ") + $0.text).font(TiskzType.small) }
                    }.padding(.top,8)
                }.padding(16).background(TiskzPalette.blue50,in:RoundedRectangle(cornerRadius:20))
            }
        }
    }
}
struct HistoryView: View {
    @EnvironmentObject var history: History
    @EnvironmentObject var settings: Settings
    @State private var confirmClear = false
    var body: some View {
        List {
                if history.records.isEmpty { ContentUnavailableView("Sin historial", systemImage:"clock", description:Text("Puedes autorizar el historial local en Ajustes. Está apagado por defecto.")) }
                ForEach(history.records) { record in
                    NavigationLink {
                        ScrollView { VStack(alignment:.leading, spacing:16) {
                            Text(record.mode).font(TiskzType.subtitle)
                            AnalysisView(analysis:record.analysis)
                            if record.analysis.clipID != nil { Text("La sesión guardó un fragmento en el servidor. El historial local no contiene el audio ni su ticket de acceso.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted) }
                            if settings.shareHistory { Button(record.uploaded ? "Volver a enviar al panel" : "Enviar esta sesión al panel") { Task { await history.upload(record, settings:settings) } }.buttonStyle(.bordered) }
                            Text(history.message).font(TiskzType.caption)
                        }.padding() }.background(TiskzPalette.background).navigationTitle("Detalle")
                    } label: {
                        CallRecordRow(record:record)
                    }
                }
                if !history.message.isEmpty { Text(history.message).font(TiskzType.caption) }
            }.listStyle(.plain).scrollContentBackground(.hidden).background(TiskzPalette.background).safeAreaInset(edge:.top,spacing:0) { TiskzTopBar(title:"Historial") { dismiss() }.background(.white) }.toolbar(.hidden,for:.navigationBar)
                .confirmationDialog("¿Eliminar el historial de este iPhone?", isPresented:$confirmClear, titleVisibility:.visible) { Button("Eliminar historial", role:.destructive) { history.clear() } }
    }
    @Environment(\.dismiss) private var dismiss
}
struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var session: CallSession
    @EnvironmentObject var history: History
    @State private var message = ""
    var body: some View {
        VStack(spacing:0) {
            TiskzTopBar(title:"Ajustes") { dismiss() }
            ScrollView {
                VStack(spacing:16) {
                    VStack(alignment:.leading,spacing:14) {
                        Text("Canal de Maritime").font(TiskzType.subtitle)
                        Text("Configura el canal seguro y el código privado del equipo.").font(TiskzType.small).foregroundStyle(TiskzPalette.muted)
                        labeledField("Canal HTTPS") {
                            TextField("https://…",text:$settings.base).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).accessibilityIdentifier("channel-url")
                        }
                        labeledField("Código privado del equipo") {
                            SecureField("Código privado",text:$settings.code).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("private-code")
                        }
                        Text("No uses la clave privada de Vapi aquí. El servidor conserva las credenciales de los proveedores.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                    }.tiskzCard()

                    VStack(alignment:.leading,spacing:14) {
                        Text("Datos de las conversaciones").font(TiskzType.subtitle)
                        Toggle("Guardar historial en este iPhone",isOn:$settings.keepHistory).tint(TiskzPalette.blue600)
                        Divider().overlay(TiskzPalette.line)
                        Toggle("Permitir envío manual al panel",isOn:$settings.shareHistory).tint(TiskzPalette.blue600)
                        Text("Son permisos independientes del análisis y del guardado de audio. Desactivar el historial no elimina sesiones existentes; usa Borrar en Historial.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                    }.tiskzCard()

                    if settings.shareHistory {
                        VStack(alignment:.leading,spacing:14) {
                            Text("API del panel").font(TiskzType.subtitle)
                            labeledField("URL HTTPS de la API") { TextField("https://…",text:$settings.panel).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL) }
                            labeledField("Organización") { TextField("ID de organización",text:$settings.org).textInputAutocapitalization(.never).autocorrectionDisabled() }
                            labeledField("API key del panel") { SecureField("Clave privada",text:$settings.panelKey).textInputAutocapitalization(.never).autocorrectionDisabled() }
                        }.tiskzCard()
                    }

                    VStack(spacing:12) {
                        Button("Guardar configuración") {
                            do { try settings.save(); message = "Configuración guardada." } catch { message = (error as? ServiceError)?.message ?? "Usa una URL HTTPS sin credenciales ni parámetros." }
                        }.buttonStyle(TiskzPrimaryButton()).disabled(session.active).accessibilityIdentifier("save-settings")
                        Button("Permitir avisos de Tiskz") { Task { let allowed = (try? await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound])) ?? false; message = allowed ? "Avisos locales habilitados." : "Puedes habilitarlos en Ajustes de iOS." } }
                            .font(TiskzType.small.weight(.semibold)).foregroundStyle(TiskzPalette.blue700).frame(maxWidth:.infinity,minHeight:48)
                        if !message.isEmpty { Text(message).font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).accessibilityIdentifier("settings-message") }
                    }.padding(4)

                    VStack(alignment:.leading,spacing:10) {
                        Text("Llamadas de operadora en iOS").font(TiskzType.subtitle)
                        Text("Tiskz no puede contestar, agregar participantes ni colgar tu llamada de la SIM automáticamente. El modo Vapi observa el canal del servidor; no captura el audio de Teléfono. El número y la conferencia se gestionan manualmente, según las condiciones de tu operadora.").font(TiskzType.small)
                        Text("Versión 0.1.0 · iOS 17 o posterior").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                    }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(TiskzPalette.blue50,in:RoundedRectangle(cornerRadius:24))
                }.padding(20)
            }.background(TiskzPalette.background).disabled(session.active)
        }.background(TiskzPalette.background)
            .toolbar(.hidden,for:.navigationBar)
    }
    private func labeledField<Field:View>(_ label:String,@ViewBuilder content:() -> Field) -> some View {
        VStack(alignment:.leading,spacing:6) {
            Text(label).font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
            content().font(TiskzType.body).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                .background(.white,in:RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).stroke(TiskzPalette.line,lineWidth:1))
        }
    }
    @Environment(\.dismiss) private var dismiss
}

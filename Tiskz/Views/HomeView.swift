import SwiftUI
import TiskzCore

/// iOS port of Android's HomeScreen: the same hero, overlapping statistics,
/// permission banner, blue information panels, recents card and round dialer FAB.
struct HomeView: View {
    @EnvironmentObject var session: CallSession
    @EnvironmentObject var history: History
    @StateObject private var contacts = ContactsBook()
    let onOpenVoice: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenDialer: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing:0) {
                    hero(topInset:geometry.safeAreaInsets.top)
                    HStack(spacing:10) {
                        stat(history.records.count,"Analizadas","Activity",TiskzPalette.blue600,TiskzPalette.blue50)
                        stat(history.records.filter { $0.analysis.alert == true }.count,"Estafas","ShieldX",TiskzPalette.red,TiskzPalette.redContainer)
                        stat(history.records.filter { $0.analysis.currentAssessment?.state == .observar }.count,"Seguras","ShieldCheck",TiskzPalette.emeraldDark,TiskzPalette.emeraldContainer)
                    }.padding(.horizontal,20).padding(.top,-44)

                    VStack(spacing:16) {
                        infoCard(
                            title:"Llamadas telefónicas",
                            detail:"En iOS, las llamadas de la SIM se gestionan desde Teléfono. Tiskz no puede contestar ni unir la conferencia automáticamente; puedes hablar con marin por el canal de voz.",
                            action:"Configurar llamadas",
                            actionHandler:onOpenSettings,
                        )
                        if !contacts.allowed { contactsBanner }
                        infoCard(
                            title:"Canal de voz en vivo",
                            detail:"Envía el micrófono a los agentes y recibe transcripción y alertas en tiempo real.",
                            action:"Abrir canal de voz",
                            actionHandler:onOpenVoice,
                        )
                        HStack(alignment:.bottom) {
                            Button(action:onOpenHistory) { Text("Recientes").font(TiskzType.title).foregroundStyle(TiskzPalette.ink) }
                                .buttonStyle(.plain).accessibilityLabel("Abrir historial completo")
                            Spacer(minLength:8)
                            Text(history.records.isEmpty ? "Sin llamadas todavía" : "\(history.records.count) llamadas")
                                .font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                        }.padding(.horizontal,4).padding(.top,12).padding(.bottom,-4)
                        if history.records.isEmpty {
                            TiskzCard {
                                VStack(spacing:12) {
                                    TablerIcon(name:"Phone").frame(width:30,height:30).foregroundStyle(TiskzPalette.blue600)
                                        .frame(width:64,height:64).background(TiskzPalette.blue50,in:Circle())
                                    Text("Aún no hay llamadas").font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink)
                                    Text("Aquí verás tus llamadas y el análisis disponible.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                                        .multilineTextAlignment(.center)
                                }.frame(maxWidth:.infinity).padding(.vertical,32).padding(.horizontal,24)
                            }
                        } else {
                            TiskzCard {
                                VStack(spacing:0) {
                                    ForEach(history.records.prefix(5)) { record in
                                        Button(action:onOpenHistory) { CallRecordRow(record:record).padding(16) }.buttonStyle(.plain)
                                        if record.id != history.records.prefix(5).last?.id { Divider().overlay(TiskzPalette.line).padding(.leading,82) }
                                    }
                                }
                            }
                        }
                        Text("Las alertas son orientaciones; no confirman identidades ni delitos.")
                            .font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                        }.padding(.horizontal,20).padding(.top,28)
                }.padding(.bottom,120)
            }
            .background(TiskzPalette.background)
            .ignoresSafeArea(edges:.top)
            .overlay(alignment:.bottomTrailing) {
                Button(action:onOpenDialer) {
                    TablerIcon(name:"GridDots").frame(width:24,height:24).foregroundStyle(.white)
                        .frame(width:64,height:64).background(TiskzPalette.brand,in:Circle())
                        .shadow(color:TiskzPalette.blue600.opacity(0.28),radius:18,x:0,y:8)
                }.padding(20).accessibilityLabel("Marcar")
            }
        }
        .background(TiskzPalette.background.ignoresSafeArea())
        .task { await contacts.refresh() }
    }

    private func hero(topInset:CGFloat) -> some View {
        VStack(spacing:0) {
            HStack(spacing:10) {
                TiskzLogo(size:38,onDark:true)
                Text("Tiskz").font(TiskzType.wordmark).foregroundStyle(.white)
                Spacer(minLength:0)
                Button(action:onOpenSettings) { TablerIcon(name:"Settings").frame(width:24,height:24).foregroundStyle(.white).frame(width:48,height:48) }.accessibilityLabel("Ajustes")
            }
            VStack(spacing:0) {
                ZStack {
                    Circle().fill(LinearGradient(colors:[.white.opacity(0.32),.white.opacity(0.12)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:84,height:84)
                    if session.connected {
                        Image("BrandShield").renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white).frame(width:56,height:56)
                    } else {
                        TablerIcon(name:"ShieldOff").frame(width:44,height:44).foregroundStyle(.white)
                    }
                }.frame(width:144,height:144)
                Text(session.connected ? "Canal conectado" : "Protección desactivada")
                    .font(TiskzType.homeTitle).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(session.connected ? "Transcripciones y orientación durante la conversación" : "Prepara Tiskz para atender con marin")
                    .font(TiskzType.homeBody).lineSpacing(2).foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center).padding(.top,4)
                Spacer().frame(height:14)
                if session.connected {
                    TiskzStatusPill(text:session.message.isEmpty ? "Canal conectado" : session.message,color:.white,container:.white.opacity(0.18))
                } else {
                    Button("Preparar Tiskz",action:onOpenSettings)
                        .font(TiskzType.homeButton).foregroundStyle(TiskzPalette.blue700)
                        .padding(.horizontal,24).frame(width:176,height:48).background(.white,in:Capsule())
                }
            }.frame(maxWidth:.infinity).padding(.top,4)
        }
        .foregroundStyle(.white)
        .padding(.leading,20).padding(.trailing,12).padding(.top,topInset > 55 ? topInset - 30 : topInset + 8).padding(.bottom,68)
        .frame(maxWidth:.infinity)
        .background(session.connected ? TiskzPalette.brand : TiskzPalette.inactive,
                    in:UnevenRoundedRectangle(bottomLeadingRadius:36,bottomTrailingRadius:36))
    }

    private func stat(_ value:Int,_ label:String,_ icon:String,_ tint:Color,_ container:Color) -> some View {
        TiskzCard(radius:22) {
            VStack(alignment:.leading,spacing:10) {
                TablerIcon(name:icon).frame(width:20,height:20).foregroundStyle(tint)
                    .frame(width:34,height:34).background(container,in:Circle())
                Text("\(value)").font(TiskzType.statValue).monospacedDigit().foregroundStyle(TiskzPalette.ink)
                Text(label).font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).lineLimit(1).minimumScaleFactor(0.85)
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
        }
    }

    private func infoCard(title:String,detail:String,action:String,actionHandler:@escaping () -> Void) -> some View {
        VStack(alignment:.leading,spacing:10) {
            Text(title).font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink)
            Text(detail).font(TiskzType.bodyMedium).lineSpacing(2).foregroundStyle(TiskzPalette.ink)
            Button(action:actionHandler) {
                Text(action).font(TiskzType.homeButton).frame(maxWidth:.infinity,minHeight:48)
                    .foregroundStyle(.white).background(TiskzPalette.blue600,in:RoundedRectangle(cornerRadius:20))
            }.buttonStyle(.plain)
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(TiskzPalette.blue50,in:RoundedRectangle(cornerRadius:24))
    }

    private var contactsBanner: some View {
        TiskzCard {
            HStack(spacing:12) {
                TablerIcon(name:"Users").frame(width:22,height:22).foregroundStyle(TiskzPalette.blue600)
                    .frame(width:44,height:44).background(TiskzPalette.blue50,in:Circle())
                VStack(alignment:.leading,spacing:4) {
                    Text("Ver nombres de contactos").font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink)
                    Text("Muestra quién llama, no solo el número.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                }
                Spacer(minLength:4)
                Button("Permitir") { Task { await contacts.refresh(requestPermission:true) } }
                    .font(TiskzType.contactButton).foregroundStyle(.white)
                    .padding(.horizontal,14).frame(height:40).background(TiskzPalette.blue600,in:Capsule())
            }.padding(16)
        }
    }
}

struct CallRecordRow: View {
    let record: CallRecord
    var body: some View {
        HStack(spacing:16) {
            CallerAvatar(size:50)
            VStack(alignment:.leading,spacing:4) {
                Text(record.mode).font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink)
                Label { Text(record.start,format:.dateTime.day().month().hour().minute()) } icon: { TablerIcon(name:"PhoneIncoming") }
                    .font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
            }
            Spacer(minLength:4)
            let colors = TiskzPalette.state(record.analysis.currentAssessment?.state)
            Text(record.analysis.currentAssessment?.state.label ?? "Sin evaluar")
                .font(TiskzType.caption.weight(.semibold)).foregroundStyle(colors.foreground)
                .padding(.horizontal,10).padding(.vertical,4).background(colors.background,in:Capsule())
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct OnboardingView: View {
    let finish: (Bool) -> Void
    var body: some View {
        ScrollView { VStack(spacing:0) {
            Spacer(minLength:24)
            TiskzLogo(size:96)
            Text("Tiskz").font(.system(.largeTitle,design:.default).bold()).foregroundStyle(TiskzPalette.blue700).padding(.top,20)
            Text("Tu teléfono, con protección contra estafas.").font(TiskzType.subtitle).multilineTextAlignment(.center).padding(.top,8)
            VStack(spacing:18) {
                feature("Headset","Un agente en la conversación","Habla con marin por internet o agrega Vapi a una conferencia manual.")
                feature("Activity","Alertas durante la conversación","Revisa transcripciones y señales de riesgo; no confirman identidades.")
                feature("Fingerprint","Una configuración inicial","Guarda el canal y el acceso. Tú decides cuándo conectar.")
            }.padding(.top,32)
            Spacer(minLength:32)
            Button("Preparar Tiskz") { finish(true) }.buttonStyle(TiskzPrimaryButton())
            Text("Configura el acceso del equipo. El micrófono se solicitará al iniciar una conversación.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).multilineTextAlignment(.center).padding(.top,8)
            Button("Probar sin activar") { finish(false) }.font(TiskzType.small.weight(.semibold)).padding(.top,12).accessibilityIdentifier("skip-onboarding")
            Text("Las llamadas de la SIM se gestionan desde Teléfono.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).multilineTextAlignment(.center).padding(.top,8)
        }.padding(24).frame(maxWidth:.infinity) }.background(.white).foregroundStyle(TiskzPalette.ink)
    }
    private func feature(_ icon:String,_ title:String,_ body:String) -> some View {
        HStack(spacing:14) {
            TablerIcon(name:icon).frame(width:24,height:24).foregroundStyle(TiskzPalette.blue600).frame(width:48,height:48).background(TiskzPalette.blue50,in:Circle())
            VStack(alignment:.leading,spacing:4) { Text(title).font(TiskzType.subtitle); Text(body).font(TiskzType.small).foregroundStyle(TiskzPalette.muted) }
            Spacer(minLength:0)
        }
    }
}

struct DialerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var number = ""
    @State private var message = ""
    private let keys:[(String,String)] = [("1",""),("2","ABC"),("3","DEF"),("4","GHI"),("5","JKL"),("6","MNO"),("7","PQRS"),("8","TUV"),("9","WXYZ"),("*",""),("0","+"),("#","")]
    var body: some View {
        VStack(spacing:0) {
            TiskzTopBar(title:"Marcar") { dismiss() }
            Spacer(minLength:24)
            HStack(spacing:8) {
                Text(number).font(TiskzType.dialNumber).foregroundStyle(TiskzPalette.ink).lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth:.infinity).accessibilityIdentifier("dialed-number")
                if !number.isEmpty {
                    Button { number.removeLast() } label: { TablerIcon(name:"Backspace").frame(width:24,height:24).foregroundStyle(TiskzPalette.muted).frame(width:44,height:44) }
                        .accessibilityLabel("Borrar dígito")
                }
            }.padding(.horizontal,32)
            Spacer(minLength:24)
            VStack(spacing:12) {
                ForEach(0..<4,id:\.self) { row in
                    HStack {
                        ForEach(keys[(row * 3)..<(row * 3 + 3)],id:\.0) { digit,letters in
                            Button { number.append(digit) } label: {
                                VStack(spacing:0) {
                                    Text(digit).font(TiskzType.dialDigit).foregroundStyle(TiskzPalette.ink)
                                    if !letters.isEmpty { Text(letters).font(TiskzType.dialLetters).tracking(1).foregroundStyle(TiskzPalette.muted) }
                                }.frame(width:76,height:76).background(TiskzPalette.blue50,in:Circle())
                            }.buttonStyle(.plain).accessibilityIdentifier("dialer-key-\(digit)")
                        }
                    }.frame(maxWidth:.infinity).frame(height:76)
                }
            }.padding(.horizontal,32)
            Spacer(minLength:12)
            Button {
                guard !number.contains("*"), !number.contains("#") else { message = "Marca los códigos de operadora directamente en Teléfono."; return }
                let safe = number.filter { $0.isNumber || $0 == "+" }
                guard safe.count >= 3, let url = URL(string:"tel:\(safe)") else { return }
                openURL(url) { accepted in if !accepted { message = "Este dispositivo no puede abrir una llamada celular." } }
            } label: {
                TablerIcon(name:"Phone").frame(width:34,height:34).foregroundStyle(.white).frame(width:76,height:76).background(TiskzPalette.blue600,in:Circle())
            }.disabled(number.filter(\.isNumber).count < 3).accessibilityLabel("Abrir llamada en Teléfono")
            Text(message).font(TiskzType.caption).foregroundStyle(TiskzPalette.red).padding(.top,8)
            Spacer(minLength:32)
        }.frame(maxWidth:.infinity,maxHeight:.infinity).background(.white)
            .toolbar(.hidden,for:.navigationBar)
    }
}

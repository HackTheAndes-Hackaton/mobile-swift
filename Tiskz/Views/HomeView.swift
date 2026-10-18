import SwiftUI
import TiskzCore

/// iOS port of Android's HomeScreen: the same hero, overlapping statistics,
/// permission banner, blue information panels, recents card and round dialer FAB.
struct HomeView: View {
    @EnvironmentObject var session: CallSession
    @EnvironmentObject var history: History
    @StateObject private var contacts = ContactsBook()
    @State private var recentPage = 0
    let onOpenVoice: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenContacts: () -> Void
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
                            title:"Filtro de llamadas",
                            detail:"En iOS, Tiskz no puede contestar automáticamente llamadas de la SIM. Puedes agregar a marin manualmente a una conferencia y recibir sus alertas.",
                            action:"Configurar llamadas",
                            actionHandler:onOpenSettings,
                        )
                        if !contacts.allowed { contactsBanner }
                        infoCard(
                            title:"Analizar una conversación",
                            detail:"Usa el micrófono para revisar en vivo una conversación y recibir alertas al instante.",
                            action:"Empezar a analizar",
                            actionHandler:onOpenVoice,
                        )
                        HStack(alignment:.bottom) {
                            Button(action:onOpenHistory) { Text("Recientes").font(TiskzType.title).foregroundStyle(TiskzPalette.ink) }
                                .buttonStyle(.plain).accessibilityLabel("Abrir historial completo")
                            Spacer(minLength:8)
                            Text(history.records.isEmpty ? "Sin llamadas todavía" : "\(history.records.count) \(history.records.count == 1 ? "llamada" : "llamadas")")
                                .font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                        }.padding(.horizontal,4).padding(.top,28).padding(.bottom,12)
                        if history.records.isEmpty {
                            TiskzCard {
                                VStack(spacing:12) {
                                    TablerIcon(name:"Phone").frame(width:30,height:30).foregroundStyle(TiskzPalette.blue600)
                                        .frame(width:64,height:64).background(TiskzPalette.blue50,in:Circle())
                                    Text("Aún no hay llamadas").font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink)
                                    Text("Aquí verás tus llamadas y qué tan seguras fueron.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                                        .multilineTextAlignment(.center)
                                }.frame(maxWidth:.infinity).padding(.vertical,32).padding(.horizontal,24)
                            }
                        } else {
                            pagedRecents
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

    private var recentPages: [[CallRecord]] {
        let records = history.records.sorted { $0.start > $1.start }
        return stride(from:0,to:records.count,by:5).map { start in
            Array(records[start..<min(start + 5,records.count)])
        }
    }

    private var pagedRecents: some View {
        let pages = recentPages
        let current = min(max(recentPage,0),max(pages.count - 1,0))
        let rowCount = pages.indices.contains(current) ? pages[current].count : 0
        return VStack(spacing:0) {
            HStack(spacing:0) {
                Button { withAnimation { recentPage = max(0,recentPage - 1) } } label: {
                    TablerIcon(name:"ChevronLeft").frame(width:20,height:20).foregroundStyle(recentPage > 0 ? TiskzPalette.blue600 : TiskzPalette.muted.opacity(0.4)).frame(width:48,height:48)
                }.disabled(recentPage <= 0).accessibilityLabel("Página anterior")
                HStack(spacing:8) {
                    ForEach(pages.indices,id:\.self) { page in
                        Button { withAnimation { recentPage = page } } label: {
                            Text("\(page + 1)").font(TiskzType.homeButton)
                                .foregroundStyle(page == current ? .white : TiskzPalette.blue700)
                                .frame(width:44,height:36)
                                .background(page == current ? TiskzPalette.blue600 : TiskzPalette.blue50,in:RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain).accessibilityLabel("Página \(page + 1)")
                    }
                }.frame(maxWidth:.infinity)
                Button { withAnimation { recentPage = min(pages.count - 1,recentPage + 1) } } label: {
                    TablerIcon(name:"ChevronRight").frame(width:20,height:20).foregroundStyle(recentPage < pages.count - 1 ? TiskzPalette.blue600 : TiskzPalette.muted.opacity(0.4)).frame(width:48,height:48)
                }.disabled(recentPage >= pages.count - 1).accessibilityLabel("Página siguiente")
            }.padding(.horizontal,12).padding(.bottom,10)
            TabView(selection:$recentPage) {
                ForEach(pages.indices,id:\.self) { page in
                    TiskzCard {
                        VStack(spacing:0) {
                            ForEach(Array(pages[page].enumerated()),id:\.element.id) { index, record in
                                Button(action:onOpenHistory) { CallRecordRow(record:record).padding(.horizontal,16).padding(.vertical,14) }.buttonStyle(.plain)
                                if index < pages[page].count - 1 { Divider().overlay(TiskzPalette.line).padding(.leading,82) }
                            }
                        }
                    }.tag(page).padding(.horizontal,20).padding(.vertical,4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode:.never))
            .frame(height:CGFloat(rowCount * 78 + max(rowCount - 1,0)))
            Text("Página \(current + 1) de \(pages.count) · desliza para ver más")
                .font(TiskzType.small).foregroundStyle(TiskzPalette.muted).frame(maxWidth:.infinity).padding(.top,8)
        }
        .onChange(of:history.records.count) { _, _ in recentPage = min(recentPage,max(recentPages.count - 1,0)) }
    }

    private func hero(topInset:CGFloat) -> some View {
        VStack(spacing:0) {
            HStack(spacing:10) {
                TiskzLogo(size:38,onDark:true)
                Text("Tiskz").font(TiskzType.wordmark).foregroundStyle(.white)
                Spacer(minLength:0)
                Button(action:onOpenContacts) {
                    TablerIcon(name:"Users").frame(width:24,height:24).foregroundStyle(.white).frame(width:48,height:48)
                }.accessibilityLabel("Contactos")
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
                Text(session.connected ? "Transcripciones y orientación durante la conversación" : "Conecta con marin y recibe alertas de riesgo")
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing:0) {
                    Spacer(minLength:24)
                    TiskzLogo(size:96)
                    Text("Tiskz").font(TiskzType.onboardingTitle).foregroundStyle(TiskzPalette.blue700).padding(.top,20)
                    Text("Tu teléfono, con protección contra estafas.").font(TiskzType.subtitle).multilineTextAlignment(.center).padding(.top,8)
                    VStack(spacing:18) {
                        feature("Headset","Tú decides cómo entrar","Habla con marin por internet o agrégala a una conferencia manual.")
                        feature("Activity","Alertas durante la conversación","Revisa transcripciones y señales de riesgo.")
                        feature("Fingerprint","Una configuración inicial","El micrófono y el guardado de voz requieren tu permiso.")
                    }.padding(.top,32)
                    Spacer(minLength:32)
                    Button("Preparar Tiskz") { finish(true) }.buttonStyle(TiskzPrimaryButton()).frame(height:60)
                    Text("Configura el canal privado. Tiskz solo conecta cuando tú lo inicias.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).multilineTextAlignment(.center).padding(.top,8)
                    Button("Probar sin activar") { finish(false) }.font(TiskzType.small.weight(.semibold)).padding(.top,12).accessibilityIdentifier("skip-onboarding")
                    Text("Las llamadas de la SIM se gestionan desde Teléfono.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).multilineTextAlignment(.center).padding(.top,8)
                }.padding(24).frame(maxWidth:.infinity).frame(minHeight:geometry.size.height)
            }
        }.background(.white).foregroundStyle(TiskzPalette.ink)
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
    let onOpenContacts: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var book = ContactsBook()
    @State private var number = ""
    @State private var message = ""
    @State private var showContactEditor = false
    private let keys:[(String,String)] = [("1",""),("2","ABC"),("3","DEF"),("4","GHI"),("5","JKL"),("6","MNO"),("7","PQRS"),("8","TUV"),("9","WXYZ"),("*",""),("0","+"),("#","")]

    private var matchingContacts: [(PhoneContact,PhoneContact.Phone)] {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 3 else { return [] }
        return Array(book.contacts.flatMap { contact in
            contact.phones.compactMap { phone in
                phone.number.filter(\.isNumber).contains(digits) ? (contact,phone) : nil
            }
        }.prefix(3))
    }

    private var topBarActions: [TiskzTopBarAction] {
        var actions: [TiskzTopBarAction] = []
        if !number.isEmpty {
            actions.append(TiskzTopBarAction(icon:"UserPlus",label:"Guardar contacto") { showContactEditor = true })
        }
        actions.append(TiskzTopBarAction(icon:"Users",label:"Contactos",action:onOpenContacts))
        return actions
    }

    var body: some View {
        VStack(spacing:0) {
            TiskzTopBar(title:"Marcar",onBack:{ dismiss() },trailing:topBarActions)
            VStack(spacing:0) {
                VStack(spacing:0) {
                    Spacer(minLength:0)
                    ForEach(Array(matchingContacts.enumerated()),id:\.offset) { item in
                        let (contact,phone) = item.element
                        Button { number = phone.number } label: {
                            HStack(spacing:10) {
                                CallerAvatar(name:contact.name,size:36)
                                VStack(alignment:.leading,spacing:2) {
                                    Text(contact.name).font(TiskzType.contactButton).foregroundStyle(TiskzPalette.ink).lineLimit(1)
                                    Text("\(phone.number) · \(phone.label)").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).lineLimit(1)
                                }
                                Spacer(minLength:0)
                            }.padding(.horizontal,8).padding(.vertical,6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.bottom)
                HStack(spacing:8) {
                    Text(number).font(TiskzType.dialNumber).foregroundStyle(TiskzPalette.ink).lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth:.infinity).accessibilityIdentifier("dialed-number")
                    if !number.isEmpty {
                        Button { number.removeLast() } label: { TablerIcon(name:"Backspace").frame(width:24,height:24).foregroundStyle(TiskzPalette.muted).frame(width:44,height:44) }
                            .accessibilityLabel("Borrar dígito")
                    }
                }.frame(maxWidth:.infinity)
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
                }
                Spacer(minLength:12)
                Button {
                    guard !number.contains("*"), !number.contains("#") else { message = "Marca los códigos de operadora directamente en Teléfono."; return }
                    let safe = number.filter { $0.isNumber || $0 == "+" }
                    guard safe.count >= 3, let url = URL(string:"tel:\(safe)") else { return }
                    openURL(url) { accepted in if !accepted { message = "Este dispositivo no puede abrir una llamada celular." } }
                } label: {
                    TablerIcon(name:"Phone").frame(width:34,height:34).foregroundStyle(.white).frame(width:76,height:76).background(TiskzPalette.blue600,in:Circle())
                }.disabled(number.filter(\.isNumber).count < 3).accessibilityLabel("Abrir llamada en Teléfono")
                if !message.isEmpty { Text(message).font(TiskzType.caption).foregroundStyle(TiskzPalette.red).padding(.top,8) }
                Spacer(minLength:32)
            }
            .padding(.horizontal,32)
            .frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .background(.white)
        .task { await book.refresh() }
        .sheet(isPresented:$showContactEditor,onDismiss:{ Task { await book.refresh() } }) {
            ContactEditor(contact:nil,initialNumber:number) { showContactEditor = false }
        }
        .toolbar(.hidden,for:.navigationBar)
    }
}

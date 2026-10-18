import SwiftUI
import TiskzCore

/// Exact sRGB tokens from mobile-repo/ui/theme/Theme.kt.
enum TiskzPalette {
    static let navy = Color(hex:0x0B1B4D), blue900 = Color(hex:0x1E3A8A)
    static let blue700 = Color(hex:0x1D4ED8), blue600 = Color(hex:0x2563EB)
    static let sky = Color(hex:0x38BDF8), blue100 = Color(hex:0xDBEAFE), blue50 = Color(hex:0xEFF6FF)
    static let white = Color.white, background = Color(hex:0xF3F6FC), ink = Color(hex:0x0F172A)
    static let muted = Color(hex:0x64748B), line = Color(hex:0xE2E8F0), surface = Color(hex:0xF1F5F9)
    static let emerald = Color(hex:0x10B981), emeraldDark = Color(hex:0x047857), emeraldContainer = Color(hex:0xD1FAE5)
    static let amber = Color(hex:0xF59E0B), amberDark = Color(hex:0xB45309), amberContainer = Color(hex:0xFEF3C7)
    static let orange = Color(hex:0xF97316), red = Color(hex:0xE11D48), redDark = Color(hex:0x9F1239), redContainer = Color(hex:0xFFE4E6)
    static let shadow = Color(hex:0x1E3A8A)
    static let brand = LinearGradient(colors:[blue900,blue600,sky], startPoint:.topLeading, endPoint:.bottomTrailing)
    static let inactive = LinearGradient(colors:[navy,blue900], startPoint:.topLeading, endPoint:.bottomTrailing)
    static let agent = LinearGradient(colors:[blue700,blue600], startPoint:.leading, endPoint:.trailing)
    static func risk(_ probability: Double?) -> Color {
        guard let p = probability else { return muted }
        if p >= 0.85 { return red }; if p >= 0.6 { return orange }; if p >= 0.3 { return amber }; return emerald
    }
    static func state(_ state: AssessmentState?) -> (foreground:Color, background:Color) {
        switch state {
        case .alertar: return (redDark,redContainer)
        case .verificar: return (amberDark,amberContainer)
        case .observar: return (blue700,blue50)
        default: return (ink,surface)
        }
    }
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red:Double((hex >> 16) & 255) / 255, green:Double((hex >> 8) & 255) / 255, blue:Double(hex & 255) / 255, opacity:1) }
}
enum TiskzType {
    static let title = Font.custom("Roboto-Bold",size:22,relativeTo:.title2)
    static let subtitle = Font.custom("Roboto-Medium",size:17,relativeTo:.body)
    static let body = Font.custom("Roboto-Regular",size:17,relativeTo:.body)
    static let bodyMedium = Font.custom("Roboto-Regular",size:15,relativeTo:.subheadline)
    static let small = Font.custom("Roboto-Regular",size:15,relativeTo:.subheadline)
    static let caption = Font.custom("Roboto-Regular",size:13,relativeTo:.footnote)
    static let homeTitle = Font.custom("Roboto-Bold",size:24,relativeTo:.title2)
    static let wordmark = Font.custom("Roboto-Bold",size:22,relativeTo:.title2)
    static let homeBody = Font.custom("Roboto-Regular",size:15,relativeTo:.subheadline)
    static let homeButton = Font.custom("Roboto-Medium",size:15,relativeTo:.subheadline)
    static let statValue = Font.custom("Roboto-Bold",size:26,relativeTo:.title2)
    static let dialNumber = Font.custom("Roboto-Regular",size:34,relativeTo:.largeTitle)
    static let dialDigit = Font.custom("Roboto-Regular",size:28,relativeTo:.title2)
    static let dialLetters = Font.custom("Roboto-Medium",size:11,relativeTo:.caption)
    static let contactButton = Font.custom("Roboto-Medium",size:14,relativeTo:.body)
}
/// Vector images are extracted from the Android drawable and Tabler Compose package.
struct TablerIcon: View {
    let name: String
    var body: some View {
        Image("Tabler\(name)").renderingMode(.template).resizable().scaledToFit().accessibilityHidden(true)
    }
}
struct TiskzTopBarAction: Identifiable {
    let icon: String
    let label: String
    let action: () -> Void
    var id: String { label }
}
struct TiskzTopBar: View {
    let title: String
    let onBack: () -> Void
    var trailing: [TiskzTopBarAction] = []
    var background: Color = TiskzPalette.white
    var body: some View {
        HStack(spacing:0) {
            Button(action:onBack) {
                TablerIcon(name:"ArrowLeft").frame(width:24,height:24).foregroundStyle(TiskzPalette.ink).frame(width:48,height:56)
            }.accessibilityLabel("Volver")
            Text(title).font(TiskzType.title).foregroundStyle(TiskzPalette.ink).lineLimit(1)
            Spacer(minLength:8)
            ForEach(trailing) { item in
                Button(action:item.action) {
                    TablerIcon(name:item.icon).frame(width:24,height:24).foregroundStyle(TiskzPalette.blue600).frame(width:44,height:56)
                }.accessibilityLabel(item.label)
            }
        }.padding(.leading,4).padding(.trailing,8).frame(maxWidth:.infinity).frame(height:56).background(background)
    }
}
struct TiskzLogo: View {
    var size: CGFloat = 72
    var onDark = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:size * 0.3).fill(onDark ? AnyShapeStyle(LinearGradient(colors:[.white.opacity(0.22),.white.opacity(0.12)], startPoint:.topLeading, endPoint:.bottomTrailing)) : AnyShapeStyle(TiskzPalette.brand))
            Image("BrandShield").renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(.white).frame(width:size * 0.56,height:size * 0.56)
        }.frame(width:size,height:size).accessibilityHidden(true)
    }
}
struct TiskzCard<Content: View>: View {
    var radius: CGFloat = 24
    @ViewBuilder let content: Content
    var body: some View { content.frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:radius)).shadow(color:TiskzPalette.shadow.opacity(0.09),radius:14,x:0,y:5) }
}
struct TiskzPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(TiskzType.subtitle).foregroundStyle(enabled ? .white : TiskzPalette.muted)
            .frame(maxWidth:.infinity,minHeight:56).background(enabled ? TiskzPalette.blue600 : TiskzPalette.line,in:RoundedRectangle(cornerRadius:20))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
struct TiskzStatusPill: View {
    var text: String
    var color: Color = TiskzPalette.blue700
    var container: Color = TiskzPalette.blue50
    var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var body: some View {
        HStack(spacing:8) {
            Circle().fill(color).frame(width:8,height:8).opacity(pulsing && pulse ? 0.25 : 1)
            Text(text).font(TiskzType.small.weight(.semibold))
        }.foregroundStyle(color).padding(.horizontal,12).padding(.vertical,6).background(container,in:Capsule())
            .onAppear { if pulsing && !reduceMotion { withAnimation(.easeInOut(duration:0.7).repeatForever(autoreverses:true)) { pulse = true } } }
    }
}
struct CallerAvatar: View {
    var name: String? = nil
    var size: CGFloat = 48
    private var initials: String {
        (name ?? "").split(separator:" ").filter { $0.first?.isLetter == true || $0.first?.isNumber == true }.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors:[TiskzPalette.blue100,TiskzPalette.blue50],startPoint:.topLeading,endPoint:.bottomTrailing))
            if !initials.isEmpty { Text(initials).font(.custom("Roboto-Bold",size:size * 0.36,relativeTo:.body)) }
            else { TablerIcon(name:"User").frame(width:size * 0.5,height:size * 0.5) }
        }.foregroundStyle(TiskzPalette.blue700).frame(width:size,height:size).accessibilityHidden(true)
    }
}
struct TiskzWaveBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moving = false
    var body: some View {
        HStack(spacing:2) { ForEach(0..<4) { i in Capsule().fill(TiskzPalette.blue600).frame(width:3,height:moving ? CGFloat(6 + i * 3) : CGFloat(15 - i * 3)).animation(reduceMotion ? nil : .easeInOut(duration:0.42 + Double(i) * 0.11).repeatForever(autoreverses:true),value:moving) } }.frame(height:16).onAppear { moving = true }
    }
}
struct AssessmentCard: View {
    let analysis: Analysis
    private var pendingAlert: Bool { analysis.currentAssessment == nil && analysis.alert == true }
    private var colors: (foreground:Color,background:Color) { TiskzPalette.state(pendingAlert ? .alertar : analysis.currentAssessment?.state) }
    private var title: String {
        if let a = analysis.currentAssessment { return a.state.label }
        if pendingAlert { return "Alerta preventiva · orientación pendiente" }
        if analysis.error != nil { return "Orientación no disponible" }
        return analysis.assessment == nil ? "Esperando orientación" : "Actualizando orientación"
    }
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).font(TiskzType.title).foregroundStyle(colors.foreground)
            Text(analysis.currentAssessment?.guidance ?? (pendingAlert ? "Hay una alerta del detector. Espera la explicación y verifica por un canal conocido." : "Esperando el análisis del fragmento actual. No se ha confirmado que la llamada sea segura.")).font(TiskzType.small)
            Text("Orientación provisional. La identidad y el origen de la voz no se han verificado.").font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(colors.background,in:RoundedRectangle(cornerRadius:20)).accessibilityElement(children:.combine)
    }
}
struct RiskBar: View {
    let analysis: Analysis
    var body: some View {
        TiskzCard {
            VStack(alignment:.leading,spacing:12) {
                HStack(alignment:.bottom) {
                    VStack(alignment:.leading,spacing:4) {
                        Text("ESTIMACIÓN DE ALERTA").font(TiskzType.caption.weight(.semibold)).tracking(1).foregroundStyle(TiskzPalette.muted)
                        Text(analysis.alert == true ? "Señales de riesgo" : analysis.probability == nil ? "Sin evaluar" : "Análisis provisional").font(TiskzType.title).foregroundStyle(TiskzPalette.risk(analysis.probability))
                    }
                    Spacer(minLength:8)
                    Text(analysis.probability.map { "\(Int($0 * 100))%" } ?? "—").font(.system(.largeTitle,design:.default).bold()).monospacedDigit().foregroundStyle(TiskzPalette.risk(analysis.probability))
                }
                GeometryReader { geometry in
                    ZStack(alignment:.leading) {
                        Capsule().fill(TiskzPalette.surface)
                        Capsule().fill(LinearGradient(colors:[TiskzPalette.risk(analysis.probability).opacity(0.55),TiskzPalette.risk(analysis.probability)],startPoint:.leading,endPoint:.trailing)).frame(width:geometry.size.width * (analysis.probability ?? 0))
                    }
                }.frame(height:12).animation(.easeInOut(duration:0.7),value:analysis.probability)
                Text("Estimación no calibrada; no confirma una estafa.").font(TiskzType.small).foregroundStyle(TiskzPalette.muted)
            }.padding(.horizontal,18).padding(.vertical,16)
        }
    }
}
struct TranscriptBubble: View {
    let caption: Caption
    private var agent: Bool { caption.speaker == "agent" }
    var body: some View {
        VStack(alignment:agent ? .trailing : .leading,spacing:6) {
            HStack(spacing:4) {
                if agent { Image("BrandShield").renderingMode(.template).resizable().scaledToFit().foregroundStyle(TiskzPalette.blue600).frame(width:16,height:16) }
                if caption.flagged { TablerIcon(name:"AlertTriangle").frame(width:16,height:16) }
                Text((agent ? "Tiskz IA · marin" : caption.label) + (caption.final ? "" : " · en curso"))
            }.font(TiskzType.small.weight(.semibold)).foregroundStyle(agent ? TiskzPalette.blue600 : caption.flagged ? TiskzPalette.red : TiskzPalette.muted).padding(.horizontal,8)
            Text(caption.text).font(TiskzType.body).textSelection(.enabled).foregroundStyle(agent ? .white : caption.flagged ? TiskzPalette.redDark : TiskzPalette.ink)
                .padding(.horizontal,16).padding(.vertical,12).frame(maxWidth:300,alignment:.leading)
                .background(agent ? AnyShapeStyle(TiskzPalette.agent) : AnyShapeStyle(caption.flagged ? TiskzPalette.redContainer : .white),in:UnevenRoundedRectangle(topLeadingRadius:22,bottomLeadingRadius:agent ? 22 : 6,bottomTrailingRadius:agent ? 6 : 22,topTrailingRadius:22))
                .shadow(color:TiskzPalette.shadow.opacity(agent ? 0 : 0.08),radius:6,x:0,y:3)
        }.frame(maxWidth:.infinity,alignment:agent ? .trailing : .leading)
    }
}
extension View {
    func tiskzCard() -> some View { padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:24)).shadow(color:TiskzPalette.shadow.opacity(0.09),radius:14,x:0,y:5) }
}

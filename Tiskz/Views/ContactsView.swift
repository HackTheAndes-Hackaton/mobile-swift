import SwiftUI
import ContactsUI

struct ContactsView: View {
    let onOpenDialer: () -> Void
    @StateObject private var book = ContactsBook()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var query = ""
    @State private var expanded: String?
    @State private var addContact = false

    var body: some View {
        VStack(spacing:0) {
            TiskzTopBar(title:"Contactos",onBack:{ dismiss() },trailing:[
                TiskzTopBarAction(icon:"UserPlus",label:"Nuevo contacto") { addContact = true }
            ],background:TiskzPalette.background)
            if !book.allowed {
                permissionPrompt
            } else {
                contactList
            }
        }
        .background(TiskzPalette.background)
        .overlay(alignment:.bottomTrailing) {
            Button(action:onOpenDialer) {
                TablerIcon(name:"GridDots").frame(width:24,height:24).foregroundStyle(.white)
                    .frame(width:64,height:64).background(TiskzPalette.brand,in:Circle())
                    .shadow(color:TiskzPalette.blue600.opacity(0.28),radius:18,x:0,y:8)
            }.padding(20).accessibilityLabel("Marcar")
        }
        .task { await book.refresh() }
        .onChange(of:phase) { _, new in if new == .active { Task { await book.refresh() } } }
        .sheet(isPresented:$addContact,onDismiss:{ Task { await book.refresh() } }) {
            ContactEditor { addContact = false }
        }
        .toolbar(.hidden,for:.navigationBar)
    }

    private var permissionPrompt: some View {
        VStack(spacing:0) {
            Spacer()
            TablerIcon(name:"Users").frame(width:48,height:48).foregroundStyle(TiskzPalette.blue600)
            Text("Permite el acceso a tus contactos").font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink).padding(.top,12)
            Text("Así puedes buscarlos y llamarlos desde Tiskz. Tus contactos se quedan en este iPhone.")
                .font(TiskzType.small).foregroundStyle(TiskzPalette.muted).multilineTextAlignment(.center)
                .padding(.top,6).padding(.bottom,16)
            Button("Permitir contactos") { Task { await book.refresh(requestPermission:true) } }
                .font(TiskzType.small.weight(.semibold)).foregroundStyle(.white).padding(.horizontal,20).frame(height:48)
                .background(TiskzPalette.blue600,in:Capsule())
            Spacer()
        }.padding(32).frame(maxWidth:.infinity,maxHeight:.infinity)
    }

    private var contactList: some View {
        ScrollView {
            VStack(spacing:8) {
                HStack(spacing:10) {
                    TablerIcon(name:"Search").frame(width:20,height:20).foregroundStyle(TiskzPalette.muted)
                    TextField("Buscar por nombre o número",text:$query).autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }.padding(.horizontal,14).frame(height:54).background(.white,in:RoundedRectangle(cornerRadius:18))
                    .padding(.horizontal,20).padding(.top,8)
                if book.loading { ProgressView("Cargando contactos…").padding() }
                let filtered = book.contacts.filter {
                    query.isEmpty || $0.name.localizedStandardContains(query) ||
                        (!query.filter(\.isNumber).isEmpty && $0.phones.contains { $0.number.filter(\.isNumber).contains(query.filter(\.isNumber)) })
                }
                let groups = Dictionary(grouping:filtered,by:{ $0.initial })
                if filtered.isEmpty && !book.loading {
                    Text(query.isEmpty ? "No tienes contactos guardados todavía." : "Ningún contacto coincide con «\(query)».")
                        .font(TiskzType.small).foregroundStyle(TiskzPalette.muted).frame(maxWidth:.infinity).padding(24)
                }
                ForEach(groups.keys.sorted(),id:\.self) { letter in
                    Text(letter).font(TiskzType.small.weight(.semibold)).foregroundStyle(TiskzPalette.blue700)
                        .frame(maxWidth:.infinity,alignment:.leading).padding(.leading,28).padding(.top,14).padding(.bottom,4)
                    ForEach(groups[letter] ?? []) { contact in contactCard(contact) }
                }
                if !book.message.isEmpty { Text(book.message).font(TiskzType.caption).foregroundStyle(TiskzPalette.redDark) }
            }.padding(.bottom,110)
        }
    }

    private func contactCard(_ contact:PhoneContact) -> some View {
        TiskzCard(radius:20) {
            VStack(spacing:0) {
                HStack(spacing:12) {
                    Button { withAnimation { expanded = expanded == contact.id ? nil : contact.id } } label: {
                        HStack(spacing:12) {
                            CallerAvatar(name:contact.name,size:44)
                            VStack(alignment:.leading,spacing:4) {
                                Text(contact.name).font(TiskzType.subtitle).foregroundStyle(TiskzPalette.ink).lineLimit(1)
                                Text(contact.phones.count > 1 ? "\(contact.phones.count) números" : contact.phones.first?.number ?? "")
                                    .font(TiskzType.caption).foregroundStyle(TiskzPalette.muted).lineLimit(1)
                            }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Spacer(minLength:0)
                    Button {
                        if contact.phones.count == 1 { call(contact.phones[0].number) }
                        else { withAnimation { expanded = expanded == contact.id ? nil : contact.id } }
                    } label: {
                        TablerIcon(name:"Phone").frame(width:20,height:20).foregroundStyle(TiskzPalette.blue600)
                            .frame(width:42,height:42).background(TiskzPalette.blue50,in:Circle())
                    }.accessibilityLabel("Llamar a \(contact.name)")
                }.padding(.horizontal,14).padding(.vertical,10)
                if expanded == contact.id {
                    Divider().overlay(TiskzPalette.line)
                    VStack(spacing:0) {
                        ForEach(contact.phones) { phone in
                            Button { call(phone.number) } label: {
                                HStack {
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(phone.number).font(TiskzType.body).foregroundStyle(TiskzPalette.ink)
                                        Text(phone.label).font(TiskzType.caption).foregroundStyle(TiskzPalette.muted)
                                    }
                                    Spacer()
                                    TablerIcon(name:"Phone").frame(width:20,height:20).foregroundStyle(TiskzPalette.blue600)
                                }.padding(.vertical,8)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.leading,70).padding(.trailing,14).padding(.bottom,10)
                }
            }
        }.padding(.horizontal,20).padding(.vertical,4)
    }

    private func call(_ number:String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string:"tel:\(digits)") { openURL(url) }
    }
}

struct ContactEditor: UIViewControllerRepresentable {
    let done: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(done:done) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact:nil); controller.contactStore = CNContactStore(); controller.delegate = context.coordinator
        return UINavigationController(rootViewController:controller)
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let done: () -> Void
        init(done:@escaping () -> Void) { self.done = done }
        func contactViewController(_ viewController:CNContactViewController,didCompleteWith contact:CNContact?) { done() }
    }
}

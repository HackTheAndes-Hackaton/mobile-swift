import XCTest
final class TiskzUITests: XCTestCase {
    private func capture(_ name:String) {
        let attachment = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launch()
        if app.buttons["skip-onboarding"].waitForExistence(timeout:3) { app.buttons["skip-onboarding"].tap() }
        return app
    }
    func testConsentAndConfiguration() {
        let app = launch()
        app.buttons["Empezar a analizar"].tap()
        XCTAssertTrue(app.buttons["connect-voice"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["connect-voice"].isEnabled)
        app.buttons["Volver"].tap()
        app.buttons["Ajustes"].tap()
        let channel = app.textFields["channel-url"]
        XCTAssertTrue(channel.waitForExistence(timeout:5))
        XCTAssertTrue((channel.value as? String ?? "").hasPrefix("https://"))
        app.buttons["save-settings"].tap()
        XCTAssertTrue(app.staticTexts["Configuración guardada."].waitForExistence(timeout:5))
        app.buttons["Volver"].tap()
        app.buttons["Abrir historial completo"].tap()
        XCTAssertTrue(app.staticTexts["Sin historial"].waitForExistence(timeout:5))
    }
    func testHomeAndDialerComponents() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Protección desactivada"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Analizadas"].exists)
        capture("Tiskz · Inicio iOS")
        app.buttons["Marcar"].tap()
        XCTAssertTrue(app.staticTexts["Marcar"].waitForExistence(timeout:5))
        capture("Tiskz · Marcador iOS")
        app.buttons["dialer-key-1"].tap(); app.buttons["dialer-key-2"].tap()
        XCTAssertFalse(app.buttons["Abrir llamada en Teléfono"].isEnabled)
        XCTAssertTrue(app.buttons["Guardar contacto"].exists)
        app.buttons["Contactos"].tap()
        XCTAssertTrue(app.staticTexts["Contactos"].waitForExistence(timeout:5))
        app.buttons["Volver"].tap()
        app.buttons["Volver"].tap()
        app.buttons["Empezar a analizar"].tap()
        XCTAssertTrue(app.buttons["connect-voice"].waitForExistence(timeout:5))
        // No network call or microphone permission is requested by visiting this screen.
        XCTAssertFalse(app.buttons["connect-voice"].isEnabled)
    }
    func testContactsPermissionStaysOptional() {
        let app = launch()
        app.buttons["Contactos"].tap()
        XCTAssertTrue(app.staticTexts["Contactos"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Permitir contactos"].exists)
        capture("Tiskz · Contactos iOS")
        app.buttons["Volver"].tap()
        app.buttons["Ajustes"].tap()
        app.buttons["open-contacts"].tap()
        XCTAssertTrue(app.staticTexts["Contactos"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Permitir contactos"].exists)
        app.buttons["Volver"].tap()
        app.buttons["Volver"].tap()
        XCTAssertTrue(app.staticTexts["Protección desactivada"].waitForExistence(timeout:5))
    }

}

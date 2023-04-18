import SwiftUI

extension Font {
    static let button = Font.custom(Epilogue.bold.rawValue, size: 20)
    static let h1 = Font.custom(Epilogue.bold.rawValue, size: 32)
    static let h4 = Font.custom(Epilogue.bold.rawValue, size: 16)
    static let h5 = Font.custom(Epilogue.medium.rawValue, size: 12)
}

enum Epilogue: String, CaseIterable {
    case bold = "Epilogue-Bold"
    case medium = "Epilogue-Medium"
}

struct CustomFont {
    public static func registerFonts() {
        Epilogue.allCases.forEach {
            registerFont(bundle: .module, fontName: $0.rawValue, fontExtension: "ttf")
        }
    }

    fileprivate static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {

        guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
                  fatalError("Couldn't create font from data")
              }

        var error: Unmanaged<CFError>?

        CTFontManagerRegisterGraphicsFont(font, &error)
    }
}

extension View {
    /// Attach this to any Xcode Preview's view to have custom fonts displayed
    /// Note: Not needed for the actual app
    public func loadCustomFonts() -> some View {
        CustomFont.registerFonts()
        return self
    }
}
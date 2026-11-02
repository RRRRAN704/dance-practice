//
//  AppTextFieldStyle.swift
//  DancePractice
//

import SwiftUI

/// Filled, rounded text field used in the app's forms.
struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .appFieldChrome()
    }
}

extension TextFieldStyle where Self == AppTextFieldStyle {
    /// Lets call sites write `.textFieldStyle(.app)`.
    static var app: AppTextFieldStyle { AppTextFieldStyle() }
}

extension View {
    /// The padding and filled background of `.app` fields, for controls that wrap a field
    /// with extra content (e.g. `PasswordField`'s eye button).
    func appFieldChrome() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.fieldRadius)
                    .fill(Theme.fieldFill)
            )
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack {
        TextField("例如：NCT DREAM", text: $text)
            .textFieldStyle(.app)
        TextField("例如：副歌部分重点练", text: $text, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.app)
    }
    .padding()
}

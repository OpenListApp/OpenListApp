import SwiftUI

extension View {
    /// 系统原生错误弹窗:绑定值非 nil 时弹出,nil 时关闭。
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "出错了",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

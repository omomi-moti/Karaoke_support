//
//  SheetHeaderView.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import SwiftUI


struct SheetHeaderView: View {
    let title : String
    let isDisabled : Bool
    /// `true` のとき、× を押すと × のそばに「変更内容を破棄」を出し、それを押したときだけ `onDismiss` を呼ぶ（#133）。
    let confirmsDiscard : Bool
    let onDismiss : () -> Void

    @State private var isConfirmingDiscard = false
    
    init(title : String, isDisabled : Bool = false, confirmsDiscard : Bool = false, onDismiss : @escaping () -> Void){
        self.title = title
        self.isDisabled = isDisabled
        self.confirmsDiscard = confirmsDiscard
        self.onDismiss = onDismiss
    }
    var body : some View{
        HStack{
            Text(title)
                .font(.title3.bold())
            Spacer()
            Button {
                if confirmsDiscard {
                    isConfirmingDiscard = true
                } else {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .disabled(isDisabled)
            .accessibilityLabel("閉じる")
            .confirmationDialog("変更内容を破棄しますか？", isPresented: $isConfirmingDiscard) {
                Button("変更内容を破棄", role: .destructive, action: onDismiss)
            }
        }
        .padding(.vertical, 6)
    }
    
}


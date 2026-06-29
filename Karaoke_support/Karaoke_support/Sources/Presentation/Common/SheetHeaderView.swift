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
    let onDismiss : () -> Void
    
    init(title : String, isDisabled : Bool = false,onDismiss : @escaping () -> Void){
        self.title = title
        self.isDisabled = isDisabled
        self.onDismiss = onDismiss
    }
    var body : some View{
        HStack{
            Text(title)
                .font(.title3.bold())
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .disabled(isDisabled)
            .accessibilityLabel("閉じる")
        }
        .padding(.vertical, 6)
    }
    
}


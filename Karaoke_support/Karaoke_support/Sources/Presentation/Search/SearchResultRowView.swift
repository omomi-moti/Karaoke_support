//
//  SearchResultRowView.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import SwiftUI

struct SearchResultRowView: View {
    let track : Track
    
    var body : some View{
        HStack{
            Text(TrackDisplayTitle.primary(for: track))
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
            
            Spacer()
            Text("\(track.singCount)回")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            
            
        }
        .padding(.vertical, 8)
        
    }
}

#Preview("Row") {
    SearchResultRowView(track: Track(userEnteredName: "アイドル", singCount: 5))
        .padding()
        .background(AppColor.backgroundGradientEnd)
}

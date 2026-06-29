//
//  SearchResultRowView.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import SwiftUI

struct SearchResultRowView: View {
    let track : Track
    
    private var latestSession: SingingSession? {
        track.sessions
            .sorted { $0.performedAt > $1.performedAt }
            .first
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    var body : some View{
        HStack{
            VStack(alignment: .leading, spacing: 4){
                Text(TrackDisplayTitle.primary(for: track))
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing : 8){
                    Label("\(track.singCount)回",systemImage:"music.mic")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    
                    if let session = latestSession{
                        Text(Self.dateFormatter.string(from: session.performedAt))
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16,style: .continuous)
                .fill(AppColor.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColor.borderSubtle, lineWidth: 1)
        )
        
    }
}

#Preview("Row") {
    SearchResultRowView(track: Track(userEnteredName: "アイドル", singCount: 5))
        .padding()
        .background(AppColor.backgroundGradientEnd)
}

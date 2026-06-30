//
//  SearchContainerView.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import SwiftUI

struct  SearchContainerView: View {
    
    let onSelectTrack : (SelectedTrack) -> Void
    
    @State private var viewModel : SearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(
        trackRepository: any TrackRepositoryProtocol,
        onSelectTrack: @escaping (SelectedTrack) -> Void
    ) {
        self.onSelectTrack = onSelectTrack
        _viewModel = State(
            initialValue: SearchViewModel(trackRepository: trackRepository)
        )
    }
    
    var body: some View{
        
            VStack(spacing: 0) {
                SheetHeaderView(title: "検索") {
                    dismiss()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                SearchView(
                    viewModel: viewModel,
                    onSelectTrack: { track in
                        let selected = SelectedTrack(
                            spotifyTrackId: track.spotifyTrackId,
                            userEnteredName: track.userEnteredName
                        )
                        if let selected {
                            Task { @MainActor in
                                onSelectTrack(selected)
                            }
                        }
                        dismiss()
                           
                    }
                        
                )
                .padding(.horizontal, 16)
            }
        }
        
    }

#Preview {
    SearchContainerView(
        trackRepository: PreviewTrackRepository(),
        onSelectTrack: { _ in }
    )
}

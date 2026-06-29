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
        NavigationStack{
            SearchView(
                viewModel: viewModel,
                onSelectTrack: { track in
                    let selected = SelectedTrack(
                        spotifyTrackId: track.spotifyTrackId,
                        userEnteredName: track.userEnteredName
                    )
                    if let selected {
                        onSelectTrack(selected)
                    }
                    dismiss()
                    
                }
            )
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement : .topBarTrailing ){
                    Button{
                        dismiss()
                    } label:{
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.pink)   
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("閉じる")
                    
                }
            }
        }
        
    }
    
}

#Preview {
    SearchContainerView(
        trackRepository: PreviewTrackRepository(),
        onSelectTrack: { _ in }
    )
}

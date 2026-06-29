//
//  SearchView.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import SwiftUI
import Observation

struct SearchView : View{
    @Bindable var viewModel: SearchViewModel
    let onSelectTrack: (Track) -> Void
    
    var body : some View{
        VStack(spacing: 0){
            TextField("曲名を検索",text : $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Divider()
            
            if viewModel.isSearching{
                Spacer()
                ProgressView()
                Spacer()
            }
            else if viewModel.result.isEmpty && !viewModel.searchText.isEmpty{
                Spacer()
                Text("該当する曲が見つかりません")
                Spacer()
            }
            else{
                List(viewModel.result) { track in
                    Button{
                        onSelectTrack(track)
                    } label:{
                        SearchResultRowView(track: track)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                
            }
            
            
        }
        .task(id: viewModel.searchText){
            await viewModel.search(query: viewModel.searchText)
        }
    }
}


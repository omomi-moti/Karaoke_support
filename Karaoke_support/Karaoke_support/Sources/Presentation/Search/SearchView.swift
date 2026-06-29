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
        VStack{
            TextField("曲名を検索",text : $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            if viewModel.isSearching{
                ProgressView()
            }
            else if viewModel.result.isEmpty && !viewModel.searchText.isEmpty{
                Text("該当する曲が見つかりません")
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
                
            }
            
            
        }
        .task(id: viewModel.searchText){
            await viewModel.search(query: viewModel.searchText)
        }
    }
}


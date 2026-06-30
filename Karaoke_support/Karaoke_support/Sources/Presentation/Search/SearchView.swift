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
            TextField("過去の歌った曲から検索しよう",text : $viewModel.searchText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
            
            Divider()
            
            if let errorMessage = viewModel.errorMessage{
                Spacer()
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.semanticError)
                    Spacer()
            }
            else if viewModel.isSearching{
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


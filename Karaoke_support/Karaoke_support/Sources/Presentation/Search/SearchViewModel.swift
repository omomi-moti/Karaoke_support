//
//  SearchViewModel.swift
//  Karaoke_support
//
//  Created by 鈴木聖也 on 2026/06/29.
//

import Foundation
import Observation

@MainActor
@Observable

final class SearchViewModel{
    private let trackRepository : any TrackRepositoryProtocol
    private var searchGeneration : UInt = 0 //何回計算が呼ばれたのか
    
    var searchText = ""
    var result : [Track] = []
    var isSearching : Bool = false
    var errorMessage : String?
    
    init(trackRepository: any TrackRepositoryProtocol){
        self.trackRepository = trackRepository
    }
    
    func search(query: String) async {
        searchGeneration += 1 //検索を呼ばれたときに世代番号をインクリメントする
        let attempt = searchGeneration //ここでの世代番号を固定
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            result = []
            errorMessage = nil
            return
        }
        
        do{
            try await Task.sleep(for: .milliseconds(300))
        }
        catch{
            return
        }
        
        guard attempt == searchGeneration else{ //ここで世代番号が違う場合はリターンする
            return
        }
        
        isSearching = true
        
        defer{
            if attempt == searchGeneration{
                isSearching = false
            }
        }
        
        do{
            let found = try await trackRepository.searchLocal(query: trimmedQuery)
            guard attempt == searchGeneration else{
                return
            }
            result = found
            errorMessage = nil
        }
        catch is CancellationError{
            return
        }
        catch{
            guard attempt == searchGeneration else { return }
            errorMessage = "検索に失敗しました。もう一度お試しください"
        }
    }
    
}

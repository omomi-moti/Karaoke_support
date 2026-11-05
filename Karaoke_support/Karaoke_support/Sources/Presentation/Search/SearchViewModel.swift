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
    /// 何も打っていない間に出す「最近歌った曲」の数（#142）。
    static let recentLimit = 5

    private let trackRepository : any TrackRepositoryProtocol
    private let trackStatsRepository: any TrackStatsRepositoryProtocol
    private var searchGeneration : UInt = 0 //何回計算が呼ばれたのか
    private var recentGeneration: UInt = 0

    var searchText = ""
    var result : [SearchResultDisplayItem] = []
    /// 打ち終わりを待っている間と、検索している間は `true`。その間 ``result`` は前の問い合わせの結果のまま。
    var isSearching : Bool = false
    var errorMessage : String?
    var recentTracks: [SearchResultDisplayItem] = []
    var recentErrorMessage: String?
    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored var calendar: Calendar = .current

    var hasActiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(trackRepository: any TrackRepositoryProtocol, trackStatsRepository: any TrackStatsRepositoryProtocol){
        self.trackRepository = trackRepository
        self.trackStatsRepository = trackStatsRepository
    }

    /// 最後に歌った日が新しい順に ``recentLimit`` 件。同じ日時なら曲の ID 順。
    func loadRecent() async {
        recentGeneration += 1
        let attempt = recentGeneration
        do {
            let stats = try await trackStatsRepository.fetchTrackSingingStats()
            guard attempt == recentGeneration else { return }
            let now = now()
            recentTracks = stats
                .sorted { a, b in
                    if a.lastPerformedAt != b.lastPerformedAt { return a.lastPerformedAt > b.lastPerformedAt }
                    return a.trackId.uuidString < b.trackId.uuidString
                }
                .prefix(Self.recentLimit)
                .map { SearchResultDisplayItem(stats: $0, now: now, calendar: calendar) }
            recentErrorMessage = nil
        } catch {
            guard attempt == recentGeneration else { return }
            recentErrorMessage = "最近歌った曲を読み込めませんでした"
        }
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

        isSearching = true

        defer{
            if attempt == searchGeneration{
                isSearching = false
            }
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

        do{
            let found = try await trackRepository.searchLocal(query: trimmedQuery)
            guard attempt == searchGeneration else{
                return
            }
            let now = now()
            result = found.map { SearchResultDisplayItem(track: $0, now: now, calendar: calendar) }
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

import Foundation

/// 検索タブで、打った文字を曲名と歌手名のどちらで探すか（#179）。
enum SearchTarget: CaseIterable {
    case name
    case artist

    var title: String {
        switch self {
        case .name: "曲名"
        case .artist: "歌手名"
        }
    }

    var systemImage: String {
        switch self {
        case .name: "music.note"
        case .artist: "music.mic"
        }
    }

    var prompt: String {
        switch self {
        case .name: "曲名で探す"
        case .artist: "歌手名で探す"
        }
    }
}

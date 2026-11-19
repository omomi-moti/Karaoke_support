import Foundation
import Testing

@testable import Karaoke_support

@Suite("TrackDisplayTitle の歌手名")
@MainActor
struct TrackDisplayTitleArtistTests {

	@Test("歌手名は前後の空白を除いて返す")
	func artistIsTrimmed() {
		let track = Track(userEnteredName: "Lemon", userEnteredArtistName: " 米津玄師 ")
		#expect(TrackDisplayTitle.artist(for: track) == "米津玄師")
	}

	@Test("歌手名がない・空白だけなら nil", arguments: [nil, "", "   "] as [String?])
	func missingArtistIsNil(artist: String?) {
		#expect(TrackDisplayTitle.artist(userEnteredArtistName: artist) == nil)
	}
}

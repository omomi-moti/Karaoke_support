import Foundation
import SwiftData
import Testing

@testable import Karaoke_support

@Suite("AppDependencies.make(configuration:)")
@MainActor
struct AppDependenciesTests {

	@Test("メモリ上の DB なら作れる")
	func makesInMemory() throws {
		let dependencies = try AppDependencies.make(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
		#expect(dependencies.modelContainer.configurations.first?.isStoredInMemoryOnly == true)
	}

	@Test("DB を開けない場所を保存先にすると throw する")
	func throwsWhenStoreCannotBeOpened() throws {
		// 保存先のフォルダにあたる場所に、ふつうのファイルを置いておく（フォルダを作れないので DB を開けない）
		let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("AppDependenciesTests-\(UUID().uuidString)")
		try Data("not a directory".utf8).write(to: blocker)
		defer { try? FileManager.default.removeItem(at: blocker) }
		let storeURL = blocker.appendingPathComponent("default.store")

		#expect(throws: (any Error).self) {
			_ = try AppDependencies.make(configuration: ModelConfiguration(url: storeURL))
		}
	}
}

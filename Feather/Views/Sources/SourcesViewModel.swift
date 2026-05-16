//
//  SourcesViewModel.swift
//  Feather
//
//  Modified for CY STORE - Smart Cache & Instant Load ⚡️
//

import Foundation
import AltSourceKit
import SwiftUI
import NimbleJSON

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	
	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else { return }
		
		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) { return }
		
		// isfinished is used to prevent multiple fetches at the same time
		isFinished = false
		defer { isFinished = true }
		
        let sourcesArray = Array(sources)
        
        // ⚡️ التعديل الأول: عرض التطبيقات المحفوظة بالذاكرة فوراً لكي لا يظهر أي تعليق
		await MainActor.run {
            if !refresh && self.sources.isEmpty {
                for source in sourcesArray {
                    if let urlString = source.sourceURL?.absoluteString,
                       let cachedRepo = loadCache(for: urlString) {
                        self.sources[source] = cachedRepo
                    }
                }
            }
            // ❌ تم حذف سطر (self.sources = [:]) الذي كان يمسح الشاشة ويجبرك على الانتظار
		}
		
		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let endIndex = min(startIndex + batchSize, sourcesArray.count)
			let batch = sourcesArray[startIndex..<endIndex]
			
			let batchResults = await withTaskGroup(of: (AltSource, ASRepository?).self, returning: [AltSource: ASRepository].self) { group in
				for source in batch {
					group.addTask {
						guard let url = source.sourceURL else {
							return (source, nil)
						}
						
						return await withCheckedContinuation { continuation in
							self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								switch result {
								case .success(let repo):
                                    // ⚡️ التعديل الثاني: حفظ التطبيقات الجديدة في الذاكرة للمرات القادمة
                                    self.saveCache(repo: repo, for: url.absoluteString)
									continuation.resume(returning: (source, repo))
								case .failure(_):
									continuation.resume(returning: (source, nil))
								}
							}
						}
					}
				}
				
				var results = [AltSource: ASRepository]()
				for await (source, repo) in group {
					if let repo {
						results[source] = repo
					}
				}
				return results
			}
			
            // تحديث الواجهة بصمت بالتطبيقات الجديدة إن وجدت
			await MainActor.run {
				for (source, repo) in batchResults {
					self.sources[source] = repo
				}
			}
		}
	}
    
    // MARK: - نظام الذاكرة المؤقتة الذكي (Smart Cache System) 🧠
    
    private func saveCache(repo: ASRepository, for urlString: String) {
        // الحفظ في الخلفية لكي لا يؤثر على سرعة التطبيق
        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(repo) {
                UserDefaults.standard.set(data, forKey: "cy_cache_\(urlString)")
            }
        }
    }

    private func loadCache(for urlString: String) -> ASRepository? {
        if let data = UserDefaults.standard.data(forKey: "cy_cache_\(urlString)"),
           let repo = try? JSONDecoder().decode(ASRepository.self, from: data) {
            return repo
        }
        return nil
    }
}

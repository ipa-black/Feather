//
//  SourcesView.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//  Modified for SY STORE - Direct Apps Display.
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
	@StateObject var viewModel = SourcesViewModel.shared
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
	
	// MARK: Body
	var body: some View {
		NBNavigationView("التطبيقات") {
            // السطر التالي هو السر: عرض قائمة التطبيقات المدمجة مباشرةً 
            // بدلاً من عرض قائمة السورسات!
			SourceAppsView(object: Array(_sources), viewModel: viewModel)
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
            _importDefaultSources() // جلب المصادر الخاصة بالمتجر تلقائياً
		}
        .refreshable {
            await viewModel.fetchSources(_sources, refresh: true)
        }
	}
    
    // MARK: - دالة استيراد المصادر الحصرية
    private func _importDefaultSources() {
        let myStoreSources = [
            "https://fastsign.dev/repo.json",
            "https://repository.apptesters.org",
            "https://raw.githubusercontent.com/ipa-black/void-repo/refs/heads/main/repo.json"
        ]
        
        for source in myStoreSources {
            let exists = _sources.contains { $0.sourceURL?.absoluteString.lowercased() == source.lowercased() }
            if !exists {
                FR.handleSource(source) { }
            }
        }
    }
}

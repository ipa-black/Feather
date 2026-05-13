//
//  HomeView.swift
//  SY STORE
//
//  Created by samara on 13.05.2026.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @StateObject var viewModel = SourcesViewModel.shared
    
    @State private var _recentApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _selectedRoute: SourceAppRoute? // استخدام النوع الجديد هنا
    @State private var isLoading = true

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    var body: some View {
        NBNavigationView("الرئيسية") {
            ZStack {
                if isLoading {
                    ProgressView("جاري جلب أحدث التطبيقات...")
                } else if _recentApps.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label("لا توجد تطبيقات", systemImage: "tray.fill")
                        } description: {
                            Text("لم يتم العثور على تطبيقات حالياً.")
                        }
                    } else {
                        Text("لا توجد تطبيقات")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section {
                            ForEach(_recentApps, id: \.app.currentUniqueId) { item in
                                Button {
                                    _selectedRoute = SourceAppRoute(source: item.source, app: item.app)
                                } label: {
                                    SourceAppsCellView(source: item.source, app: item.app)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("أحدث الإضافات")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            // إصلاح الخطأ: استخدام الدالة المباشرة هنا
            .navigationDestination(item: $_selectedRoute) { route in
                SourceAppsDetailView(source: route.source, app: route.app)
            }
            .refreshable {
                await viewModel.fetchSources(_sources, refresh: true)
                _loadRecentApps()
            }
        }
        .task(id: Array(_sources)) {
            await viewModel.fetchSources(_sources)
            _loadRecentApps()
        }
    }

    private func _loadRecentApps() {
        isLoading = true
        Task {
            let loadedSources = _sources.compactMap { viewModel.sources[$0] }
            var allApps: [(source: ASRepository, app: ASRepository.App)] = []

            for source in loadedSources {
                for app in source.apps {
                    allApps.append((source: source, app: app))
                }
            }

            allApps.sort {
                ($0.app.currentDate?.date ?? .distantPast) > ($1.app.currentDate?.date ?? .distantPast)
            }

            let topApps = Array(allApps.prefix(25))

            DispatchQueue.main.async {
                self._recentApps = topApps
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Types
// تعريف النوع هنا لضمان عدم وجود خطأ في الوصول إليه
struct SourceAppRoute: Identifiable, Hashable {
    let source: ASRepository
    let app: ASRepository.App
    let id: String = UUID().uuidString
}

// MARK: - Extension for Navigation
extension View {
    @ViewBuilder
    func navigationDestination<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        self.navigationDestination(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let selectedItem = item.wrappedValue {
                destination(selectedItem)
            }
        }
    }
}

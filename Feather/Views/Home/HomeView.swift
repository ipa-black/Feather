//
//  HomeView.swift
//  SY STORE
//
//  Created by samara on 13.05.2025.
//  New file created for SY STORE.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @StateObject var viewModel = SourcesViewModel.shared
    
    // مصفوفة لتخزين أحدث التطبيقات
    @State private var _recentApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _selectedRoute: SourceAppsView.SourceAppRoute?
    @State private var isLoading = true

    // جلب المصادر المحفوظة في التطبيق
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
                            Text("لم يتم العثور على تطبيقات في المصادر الحالية.")
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
                                    _selectedRoute = SourceAppsView.SourceAppRoute(source: item.source, app: item.app)
                                } label: {
                                    // استخدام نفس تصميم الخلية الاحترافي الذي عدلناه سابقاً
                                    SourceAppsCellView(source: item.source, app: item.app)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("أحدث الإضافات والتحديثات")
                                .font(.headline)
                                .foregroundColor(.primary)
                        } footer: {
                            Text("يتم تحديث هذه القائمة تلقائياً بأحدث التطبيقات من مصادرك.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            // الانتقال إلى صفحة تفاصيل التطبيق عند الضغط عليه
            .navigationDestinationIfAvailable(item: $_selectedRoute) { route in
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
        .onChange(of: viewModel.isFinished) { _ in
            _loadRecentApps()
        }
    }

    // MARK: - دالة ترتيب وجلب أحدث التطبيقات
    private func _loadRecentApps() {
        isLoading = true
        
        Task {
            // 1. استخراج المصادر الجاهزة
            let loadedSources = _sources.compactMap { viewModel.sources[$0] }
            var allApps: [(source: ASRepository, app: ASRepository.App)] = []

            // 2. دمج جميع التطبيقات من جميع المصادر
            for source in loadedSources {
                for app in source.apps {
                    allApps.append((source: source, app: app))
                }
            }

            // 3. ترتيب التطبيقات حسب التاريخ (الأحدث أولاً)
            allApps.sort {
                let d1 = $0.app.currentDate?.date ?? .distantPast
                let d2 = $1.app.currentDate?.date ?? .distantPast
                return d1 > d2
            }

            // 4. أخذ أول 25 تطبيق فقط لعرضها في الصفحة الرئيسية
            let topApps = Array(allApps.prefix(25))

            // 5. تحديث الواجهة
            DispatchQueue.main.async {
                self._recentApps = topApps
                self.isLoading = false
            }
        }
    }
}

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
    @State private var _banners: [StoreBanner] = [] // تخزين البنرات
    @State private var _selectedRoute: SourceAppRoute?
    @State private var isLoading = true

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    var body: some View {
        NBNavigationView("الرئيسية") {
            ZStack {
                if isLoading && _recentApps.isEmpty && _banners.isEmpty {
                    ProgressView("جاري التحديث...")
                } else if _recentApps.isEmpty && _banners.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label("لا توجد تطبيقات", systemImage: "tray.fill")
                        } description: {
                            Text("لم يتم العثور على تطبيقات أو عروض حالياً.")
                        }
                    } else {
                        Text("لا توجد تطبيقات")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // MARK: - قسم البنرات الإعلانية (Swipeable)
                        if !_banners.isEmpty {
                            Section {
                                TabView {
                                    ForEach(_banners) { banner in
                                        Button {
                                            if let link = banner.link, let url = URL(string: link) {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            AsyncImage(url: URL(string: banner.imageURL)) { phase in
                                                if let image = phase.image {
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } else if phase.error != nil {
                                                    Rectangle()
                                                        .fill(Color(uiColor: .secondarySystemBackground))
                                                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                                } else {
                                                    Rectangle()
                                                        .fill(Color(uiColor: .secondarySystemBackground))
                                                        .overlay(ProgressView())
                                                }
                                            }
                                            // أبعاد البنر ليتناسب مع الشاشة
                                            .frame(height: 190)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .padding(.horizontal, 16)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(height: 230)
                                // هذه الخاصية هي التي تعطي تأثير السحب يميناً ويساراً مع النقاط السفلية
                                .tabViewStyle(.page(indexDisplayMode: .always))
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }

                        // MARK: - قسم أحدث التطبيقات
                        if !_recentApps.isEmpty {
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
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                    .padding(.top, 5)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationDestination(item: $_selectedRoute) { route in
                SourceAppsDetailView(source: route.source, app: route.app)
            }
            .refreshable {
                await viewModel.fetchSources(_sources, refresh: true)
                _loadRecentApps()
                _loadBanners()
            }
        }
        .task(id: Array(_sources)) {
            await viewModel.fetchSources(_sources)
            _loadRecentApps()
            _loadBanners()
        }
    }

    // MARK: - جلب أحدث التطبيقات
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
    
    // MARK: - جلب البنرات الإعلانية من السورس
    private func _loadBanners() {
        Task {
            guard let url = URL(string: "https://raw.githubusercontent.com/ipa-black/void-repo/refs/heads/main/repo.json") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(RepoBannerResponse.self, from: data)
                
                DispatchQueue.main.async {
                    // التعديل هنا: نأخذ أول بنرين فقط (prefix 2) لضمان عدم زيادة العدد عن اثنين
                    self._banners = Array((response.banners ?? []).prefix(2))
                }
            } catch {
                print("فشل جلب البنرات: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Types for Banners
struct StoreBanner: Decodable, Identifiable {
    var id: String { imageURL }
    let imageURL: String
    let link: String?
}

struct RepoBannerResponse: Decodable {
    let banners: [StoreBanner]?
}

// MARK: - Supporting Types
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

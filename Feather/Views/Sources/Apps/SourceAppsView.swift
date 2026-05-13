//
//  SourceAppsView.swift
//  SY STORE
//
//  Created by samara on 1.05.2025.
//  Modified for SY STORE.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

// MARK: - Extension: View (Enil & Categories)
extension SourceAppsView {
	enum SortOption: String, CaseIterable {
		case `default` = "default"
		case name
		case date
		
		var displayName: String {
			switch self {
			case .default:  return "الافتراضي"
			case .name: 	return "الاسم"
			case .date: 	return "التاريخ"
			}
		}
	}
    
    enum AppCategory: String, CaseIterable {
        case all = "الكل"
        case social = "اجتماعي"
        case entertainment = "ترفيه"
        case games = "ألعاب"
        case photoVideo = "صورة فيديو"
        case developer = "مطور"
        case lifestyle = "نمط الحياة"
        case other = "غير ذلك"
    }
}

// MARK: - View
struct SourceAppsView: View {
	@AppStorage("SYStore.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.default.rawValue
	@AppStorage("SYStore.sortAscending") private var _sortAscending: Bool = true
	
	@State private var _sortOption: SortOption = .default
	@State private var _selectedRoute: SourceAppRoute?
    @State private var _selectedCategory: AppCategory = .all
	
	@State var isLoading = true
	@State var hasLoadedOnce = false
	@State private var _searchText = ""

	private var _navigationTitle: String {
		if object.count == 1 {
			return object[0].name ?? "غير معروف"
		} else {
			return "\(object.count) مصادر"
		}
	}
	
	var object: [AltSource]
	@ObservedObject var viewModel: SourcesViewModel
	@State private var _sources: [ASRepository]?
	
	// MARK: Body
	var body: some View {
		ZStack {
			if
				let _sources,
				!_sources.isEmpty
			{
				SourceAppsTableRepresentableView(
					sources: _sources,
					searchText: $_searchText,
					sortOption: $_sortOption,
					sortAscending: $_sortAscending,
                    selectedCategory: $_selectedCategory, // تمرير التصنيف
					onSelect: {self._selectedRoute = $0}
				)
				.ignoresSafeArea()
			} else {
				ProgressView()
			}
		}
		.navigationTitle(_navigationTitle)
		.searchable(text: $_searchText, placement: .platform(), prompt: "ابحث في التطبيقات...")
		.toolbarTitleMenu {
			if
				let _sources,
				_sources.count == 1
			{
				if let url = _sources[0].website {
					Button("زيارة الموقع", systemImage: "globe") {
						UIApplication.open(url)
					}
				}
			}
		}
		.toolbar {
			NBToolbarMenu(
				systemImage: "line.3.horizontal.decrease",
				style: .icon,
				placement: .topBarTrailing
			) {
				_categoryActions()
                Divider()
				_sortActions()
			}
		}
		.onAppear {
			if !hasLoadedOnce, viewModel.isFinished {
				_load()
				hasLoadedOnce = true
			}
			_sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
		}
		.onChange(of: viewModel.isFinished) { _ in
			_load()
		}
		.onChange(of: _sortOption) { newValue in
			_sortOptionRawValue = newValue.rawValue
		}
		.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
			SourceAppsDetailView(source: route.source, app: route.app)
		}
	}
	
	private func _load() {
		isLoading = true
		
		Task {
			let loadedSources = object.compactMap { viewModel.sources[$0] }
			_sources = loadedSources
			withAnimation(.easeIn(duration: 0.2)) {
				isLoading = false
			}
		}
	}
	
	struct SourceAppRoute: Identifiable, Hashable {
		let source: ASRepository
		let app: ASRepository.App
		let id: String = UUID().uuidString
	}
}

// MARK: - Extension: View (Sort & Category)
extension SourceAppsView {
    
    @ViewBuilder
    private func _categoryActions() -> some View {
        Section("التصنيفات") {
            ForEach(AppCategory.allCases, id: \.self) { category in
                Button {
                    _selectedCategory = category
                } label: {
                    HStack {
                        Text(category.rawValue)
                        Spacer()
                        if _selectedCategory == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

	@ViewBuilder
	private func _sortActions() -> some View {
		Section("ترتيب حسب") {
			ForEach(SortOption.allCases, id: \.displayName) { opt in
				_sortButton(for: opt)
			}
		}
	}
	
	private func _sortButton(for option: SortOption) -> some View {
		Button {
			if _sortOption == option {
				_sortAscending.toggle()
			} else {
				_sortOption = option
				_sortAscending = true
			}
		} label: {
			HStack {
				Text(option.displayName)
				Spacer()
				if _sortOption == option {
					Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
				}
			}
		}
	}
}

import SwiftUI

extension View {
	@ViewBuilder
	func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
		item: Binding<Item?>,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) -> some View {
		if #available(iOS 17, *) {
			self.navigationDestination(item: item, destination: destination)
		} else {
			self
		}
	}
}

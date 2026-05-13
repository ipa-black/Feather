//
//  SigningView.swift
//  SY STORE
//
//  Created by samara on 14.04.2025.
//  Modified for SY STORE.
//

import SwiftUI
import PhotosUI
import NimbleViews

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	
    // متغير جديد خاص بتكرار التطبيقات
    @State private var _duplicationCount: Int = 0
    
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable) {
		self.app = app
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
	var body: some View {
		NBNavigationView("توقيع التطبيق", displayMode: .inline) {
			Form {
				_customizationOptions(for: app)
				_cert()
				_customizationProperties(for: app)
				
				Rectangle()
					.foregroundStyle(.clear)
					.frame(height: 30)
					.listRowBackground(EmptyView())
			}
            .scrollContentBackground(.hidden) 
            .background {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
			.overlay {
				VStack(spacing: 0) {
					Spacer()
					NBVariableBlurView()
						.frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 60 : 80)
						.rotationEffect(.degrees(180))
						.overlay {
							Button {
								_start()
							} label: {
								NBSheetButton(title: "بدء التوقيع", style: .prominent)
									.padding()
							}
							.buttonStyle(.plain)
							.offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -20 : -40)
						}
				}
				.ignoresSafeArea(edges: .bottom)
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				NBToolbarButton(
					"إعادة تعيين",
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
                    _duplicationCount = 0
                    _updateBundleID()
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
				.ignoresSafeArea()
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
		}
	}
    
    private func _updateBundleID() {
        let baseBundle = app.identifier ?? "com.unknown.app"
        if _duplicationCount > 0 {
            _temporaryOptions.appIdentifier = "\(baseBundle)\(_duplicationCount)"
        } else {
            _temporaryOptions.appIdentifier = baseBundle
        }
    }
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		NBSection("التخصيص") {
            // تصغير حجم الأيقونة العلوية لتبدو أبسط
			Menu {
				Button("اختيار أيقونة بديلة", systemImage: "app.dashed") { _isAltPickerPresenting = true }
				Button("اختيار من الملفات", systemImage: "folder") { _isFilePickerPresenting = true }
				Button("اختيار من الصور", systemImage: "photo") { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle()
				} else {
					FRAppIconView(app: app, size: 48) // تم تصغير الحجم هنا من 56 إلى 48
				}
			}
			
			_infoCell("الاسم", desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: "الاسم",
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell("المعرّف", desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: "المعرّف",
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
            
            // قسم التكرار المبسط والمتناسق
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("تكرار التطبيق")
                    Spacer()
                    
                    // أزرار أنيقة ومصغرة
                    HStack(spacing: 12) {
                        Button(action: {
                            if _duplicationCount > 0 {
                                _duplicationCount -= 1
                                _updateBundleID()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3) // تصغير الأزرار
                                .foregroundColor(_duplicationCount > 0 ? .red : .gray.opacity(0.5))
                        }
                        .buttonStyle(.borderless)

                        Text("\(_duplicationCount)")
                            .font(.body.monospacedDigit()) // خط رقمي مرتب
                            .frame(width: 20, alignment: .center)

                        Button(action: {
                            _duplicationCount += 1
                            _updateBundleID()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3) // تصغير الأزرار
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                Text("اضغط على + لتكرار التطبيق")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
            
			_infoCell("الإصدار", desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: "الإصدار",
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		NBSection("التوقيع") {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			} else {
				Text("لا توجد شهادة")
					.font(.footnote)
					.foregroundColor(.disabled())
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		NBSection("متقدم") {
			DisclosureGroup("تعديل") {
				NavigationLink("مكتبات Dylibs") {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink("الإطارات والإضافات") {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				#if NIGHTLY || DEBUG
					NavigationLink("التصريحات (Entitlements)") {
						SigningEntitlementsView(
							bindingValue: $_temporaryOptions.appEntitlementsFile
						)
					}
				#endif
				NavigationLink("التعديلات (Tweaks)") {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink("الخصائص") {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle("الخصائص")
			}
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? "غير معروف")
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard
			_selectedCert() != nil || _temporaryOptions.signingOption != .default
		else {
			UIAlertController.showAlertWithOk(
				title: "لا توجد شهادة",
				message: "يرجى الذهاب إلى الإعدادات واستيراد شهادة صالحة",
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true
		
		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { error in
			if let error {
				let ok = UIAlertAction(title: "إغلاق", style: .cancel) { _ in
					dismiss()
				}
				
				UIAlertController.showAlert(
					title: "خطأ",
					message: error.localizedDescription,
					actions: [ok]
				)
			} else {
				if
					_temporaryOptions.post_deleteAppAfterSigned,
					!app.isSigned
				{
					Storage.shared.deleteApp(for: app)
				}
				
				if _temporaryOptions.post_installAppAfterSigned {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
						NotificationCenter.default.post(name: Notification.Name("SYStore.installApp"), object: nil)
					}
				}
				dismiss()
			}
		}
	}
}

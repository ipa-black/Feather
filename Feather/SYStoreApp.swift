//
//  SYStoreApp.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//  Modified for CY STORE - VIP Smart Scanner & Firebase Fix 📱⚡️.
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog
import CoreData

// MARK: - مدير الحماية والتحقق من الاشتراك (StoreAuthManager)
class StoreAuthManager: ObservableObject {
    static let shared = StoreAuthManager()
    
    @Published var isAuthorized: Bool = false
    @Published var isChecking: Bool = true
    @Published var errorMessage: String? = nil
    
    // الرابط الأساسي لقاعدة البيانات
    let firebaseDB = "https://systore-b04e9-default-rtdb.firebaseio.com"
    
    init() {
        checkAuthOnLaunch()
    }
    
    func checkAuthOnLaunch() {
        guard let userCode = UserDefaults.standard.string(forKey: "activation_code") else {
            DispatchQueue.main.async {
                self.isChecking = false
                self.isAuthorized = false
            }
            return
        }
        
        verifyCodeFromServer(code: userCode) { success, message in
            DispatchQueue.main.async {
                self.isChecking = false
                self.isAuthorized = success
                self.errorMessage = message
            }
        }
    }
    
    func verifyCodeFromServer(code: String, completion: @escaping (Bool, String?) -> Void) {
        // 1. تنظيف كود المشترك للبحث عنه بجوهره فقط (بدون cy- ومسافات)
        var userInput = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if userInput.hasPrefix("cy-") { userInput = String(userInput.dropFirst(3)) }
        else if userInput.hasPrefix("cy") { userInput = String(userInput.dropFirst(2)) }
        
        // 2. جلب جميع الأكواد من السيرفر للبحث الذكي (تجاهل الحروف الكبيرة والصغيرة)
        guard let url = URL(string: "\(firebaseDB)/codes.json") else {
            completion(false, "رابط السيرفر غير صالح.")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(false, "تعذر الاتصال بالسيرفر. تأكد من الإنترنت.")
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8),
                   jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    completion(false, "قاعدة البيانات فارغة! قم بتوليد كود من البوت أولاً.")
                    return
                }
                
                guard let codesDict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
                    completion(false, "فشل في قراءة البيانات من السيرفر.")
                    return
                }
                
                var exactDbKey: String? = nil
                var foundCodeData: [String: Any]? = nil
                
                // 3. البحث الذكي داخل السيرفر (يطابق أي كود مهما كانت طريقة كتابته)
                for (key, value) in codesDict {
                    var dbKeyClean = key.lowercased()
                    if dbKeyClean.hasPrefix("cy-") { dbKeyClean = String(dbKeyClean.dropFirst(3)) }
                    else if dbKeyClean.hasPrefix("cy") { dbKeyClean = String(dbKeyClean.dropFirst(2)) }
                    
                    if dbKeyClean == userInput {
                        exactDbKey = key
                        foundCodeData = value as? [String: Any]
                        break
                    }
                }
                
                if let exactKey = exactDbKey, let codeData = foundCodeData {
                    let status = codeData["status"] as? String ?? "unknown"
                    
                    if status == "suspended" {
                        completion(false, "تم تجميد اشتراكك ❄️ يرجى مراجعة الإدارة.")
                    } else if status == "revoked" {
                        completion(false, "تم إيقاف اشتراكك ⛔ الكود تالف أو تم تعويضه.")
                    } else if status == "used" || status == "valid" {
                        // حفظ الكود الدقيق كما هو موجود في السيرفر
                        UserDefaults.standard.set(exactKey, forKey: "activation_code")
                        if status == "valid" { self.markCodeAsUsed(exactKey) }
                        completion(true, nil)
                    } else {
                        completion(false, "حالة الكود غير معروفة.")
                    }
                } else {
                    completion(false, "الكود غير صحيح أو غير موجود.")
                }
                
            } catch {
                completion(false, "حدث خطأ غير متوقع في معالجة البيانات.")
            }
        }.resume()
    }
    
    private func markCodeAsUsed(_ exactKey: String) {
        guard let url = URL(string: "\(firebaseDB)/codes/\(exactKey).json") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UnknownDevice"
        let body: [String: Any] = ["status": "used", "usedDate": ISO8601DateFormatter().string(from: Date()), "udid": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "activation_code")
        self.isAuthorized = false
    }
}


// MARK: - شاشة التفعيل الفخمة (Native iOS Style) 📱
struct ActivationView: View {
    @State private var codeInput: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @ObservedObject var authManager = StoreAuthManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 65))
                            .foregroundColor(.accentColor)
                            .padding(.top, 10)
                        
                        Text("CY STORE VIP")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("يرجى إدخال كود التفعيل الخاص بك للوصول إلى متجر التطبيقات والشهادات.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("معلومات الاشتراك")) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        TextField("CY-XXXXXX", text: $codeInput)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                    }
                }
                
                Section {
                    Button(action: activateCode) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("تفعيل المتجر")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(codeInput.isEmpty || isLoading)
                }
                
                Section {
                    if let error = authManager.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://t.me/ipa_black") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("ليس لديك كود؟ شراء كود تفعيل")
                        }
                        .font(.callout)
                    }
                }
            }
            .navigationTitle("تفعيل الحساب")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("تنبيه"), message: Text(alertMessage), dismissButton: .default(Text("حسناً")))
            }
        }
    }
    
    private func activateCode() {
        isLoading = true
        authManager.verifyCodeFromServer(code: codeInput) { success, message in
            isLoading = false
            if !success {
                self.alertMessage = message ?? "حدث خطأ غير معروف."
                self.showAlert = true
            }
        }
    }
}


// MARK: - التطبيق الأساسي (الموجه)
@main
struct SYStoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var authManager = StoreAuthManager.shared
    let heartbeat = HeartbeatManager.shared
    @StateObject var downloadManager = DownloadManager.shared
    let storage = Storage.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isChecking {
                    VStack { ProgressView("جاري فحص الاشتراك...") }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(UIColor.systemBackground))
                } else if authManager.isAuthorized {
                    VStack {
                        DownloadHeaderView(downloadManager: downloadManager)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        VariedTabbarView()
                            .environment(\.managedObjectContext, storage.context)
                            .onOpenURL(perform: _handleURL)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .animation(.smooth, value: downloadManager.manualDownloads.description)
                    .onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
                        DispatchQueue.main.async { UIAlertController.showAlertWithOk(title: "خطأ في ملف الربط", message: "ملف الربط الخاص بك غير متوافق مع هذا الجهاز.") }
                    }
                } else {
                    ActivationView()
                }
            }
            .onAppear {
                if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "Feather.userInterfaceStyle")) { UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style }
                let storedHex = UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#16BFE0"
                UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: storedHex))
            }
        }
    }
    
    private func _handleURL(_ url: URL) {
        if url.scheme == "systore" {
            if url.host == "import-certificate" {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else { return }
                func queryValue(_ name: String) -> String? { queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding }
                guard let p12Base64 = queryValue("p12"), let provisionBase64 = queryValue("mobileprovision"), let passwordBase64 = queryValue("password"), let passwordData = Data(base64Encoded: passwordBase64), let password = String(data: passwordData, encoding: .utf8) else { return }
                let generator = UINotificationFeedbackGenerator(); generator.prepare()
                guard let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"), let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"), FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL) else { generator.notificationOccurred(.error); return }
                FR.handleCertificateFiles(p12URL: p12URL, provisionURL: provisionURL, p12Password: password) { error in
                    if let error = error { UIAlertController.showAlertWithOk(title: "خطأ", message: error.localizedDescription) } else { generator.notificationOccurred(.success) }
                }
                return
            }
            if let fullPath = url.validatedScheme(after: "/source/") { FR.handleSource(fullPath) { } }
            if let fullPath = url.validatedScheme(after: "/install/"), let downloadURL = URL(string: fullPath) { _ = DownloadManager.shared.startDownload(from: downloadURL) }
        } else {
            if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
                if FileManager.default.isFileFromFileProvider(at: url) { guard url.startAccessingSecurityScopedResource() else { return }; FR.handlePackageFile(url) { _ in } } else { FR.handlePackageFile(url) { _ in } }
                return
            }
        }
    }
}

// MARK: - AppDelegate & Direct Signer
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _createPipeline()
        _createDocumentsDirectories()
        ResetView.clearWorkCache()
        _addDefaultCertificates()
        return true
    }
    
    // 🔥 دالة الربط المباشر الصاروخية للتوقيع
    func performDirectAutoSign(downloadId: String) {
        let context = Storage.shared.context
        
        let appRequest = Imported.fetchRequest()
        appRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
        appRequest.fetchLimit = 1
        
        guard let latestApp = try? context.fetch(appRequest).first else {
            DispatchQueue.main.async { DownloadManager.shared.removeDownload(id: downloadId) }
            return
        }
        
        let certRequest = CertificatePair.fetchRequest()
        certRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
        guard let certs = try? context.fetch(certRequest), !certs.isEmpty else {
            DispatchQueue.main.async {
                DownloadManager.shared.removeDownload(id: downloadId)
                UIAlertController.showAlertWithOk(title: "تنبيه", message: "لا توجد شهادة لتوقيعه تلقائياً.")
            }
            return
        }
        
        let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        let cert = certs.indices.contains(selectedIndex) ? certs[selectedIndex] : certs.first!
        let options = OptionsManager.shared.options
        
        FR.signPackageFile(latestApp, using: options, icon: nil, certificate: cert) { error in
            DispatchQueue.main.async {
                DownloadManager.shared.removeDownload(id: downloadId)
                
                if let error = error {
                    UIAlertController.showAlertWithOk(title: "فشل التوقيع التلقائي", message: error.localizedDescription)
                } else {
                    if options.post_deleteAppAfterSigned { Storage.shared.deleteApp(for: latestApp) }
                    NotificationCenter.default.post(name: Notification.Name("SYStore.installApp"), object: nil)
                }
            }
        }
    }
    
    private func _createPipeline() {
        DataLoader.sharedUrlCache.diskCapacity = 0
        let pipeline = ImagePipeline {
            let dataLoader: DataLoader = { let config = URLSessionConfiguration.default; config.urlCache = nil; return DataLoader(configuration: config) }()
            let dataCache = try? DataCache(name: "com.systore.datacache")
            let imageCache = Nuke.ImageCache()
            dataCache?.sizeLimit = 500 * 1024 * 1024; imageCache.costLimit = 100 * 1024 * 1024
            $0.dataCache = dataCache; $0.imageCache = imageCache; $0.dataLoader = dataLoader; $0.dataCachePolicy = .automatic; $0.isStoringPreviewsInMemoryCache = false
        }
        ImagePipeline.shared = pipeline
    }
    private func _createDocumentsDirectories() {
        let fileManager = FileManager.default
        let directories: [URL] = [fileManager.archives, fileManager.certificates, fileManager.signed, fileManager.unsigned]
        for url in directories { try? fileManager.createDirectoryIfNeeded(at: url) }
    }
    private func _addDefaultCertificates() {
        guard UserDefaults.standard.bool(forKey: "systore.didImportDefaultCertificates") == false, let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil) else { return }
        do {
            let folderContents = try FileManager.default.contentsOfDirectory(at: signingAssetsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for folderURL in folderContents {
                guard folderURL.hasDirectoryPath else { continue }
                let certName = folderURL.lastPathComponent
                let p12Url = folderURL.appendingPathComponent("cert.p12"); let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision"); let passwordUrl = folderURL.appendingPathComponent("cert.txt")
                guard FileManager.default.fileExists(atPath: p12Url.path), FileManager.default.fileExists(atPath: provisionUrl.path), FileManager.default.fileExists(atPath: passwordUrl.path) else { continue }
                let password = try String(contentsOf: passwordUrl, encoding: .utf8)
                FR.handleCertificateFiles(p12URL: p12Url, provisionURL: provisionUrl, p12Password: password, certificateName: certName, isDefault: true) { _ in }
            }
            UserDefaults.standard.set(true, forKey: "systore.didImportDefaultCertificates")
        } catch { Logger.misc.error("Failed to list signing-assets: \(error)") }
    }
}

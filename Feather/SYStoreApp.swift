//
//  SYStoreApp.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//  Modified for CY STORE - VIP Lock Screen & Direct AutoSign ⚡️.
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
    
    let firebaseURL = "https://systore-b04e9-default-rtdb.firebaseio.com/codes/"
    
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
        var cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanCode.hasPrefix("cy-") { cleanCode = "cy-\(cleanCode)" }
        
        guard let url = URL(string: "\(firebaseURL)\(cleanCode).json") else {
            completion(false, "رابط التحقق غير صالح.")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(false, "تعذر الاتصال بالسيرفر. تأكد من الإنترنت.")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    
                    if status == "suspended" {
                        completion(false, "تم تجميد اشتراكك ❄️ يرجى مراجعة الإدارة.")
                    } else if status == "revoked" {
                        completion(false, "تم إيقاف اشتراكك ⛔ الكود تالف أو تم تعويضه.")
                    } else if status == "used" || status == "valid" {
                        UserDefaults.standard.set(cleanCode, forKey: "activation_code")
                        if status == "valid" { self.markCodeAsUsed(code: cleanCode) }
                        completion(true, nil)
                    } else {
                        completion(false, "حالة الكود غير معروفة.")
                    }
                } else {
                    completion(false, "الكود غير صحيح أو تم حذفه من النظام.")
                }
            } catch {
                completion(false, "خطأ في قراءة بيانات السيرفر.")
            }
        }.resume()
    }
    
    private func markCodeAsUsed(code: String) {
        guard let url = URL(string: "\(firebaseURL)\(code).json") else { return }
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


// MARK: - شاشة التفعيل الفخمة (ActivationView)
struct ActivationView: View {
    @State private var codeInput: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @ObservedObject var authManager = StoreAuthManager.shared
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                Image(systemName: "lock.shield.fill").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.blue)
                Text("CY STORE VIP").font(.largeTitle).fontWeight(.bold)
                Text("يرجى إدخال كود التفعيل الخاص بك للوصول إلى متجر التطبيقات والشهادات.")
                    .multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 40)
                
                VStack(spacing: 15) {
                    TextField("CY-XXXXXX", text: $codeInput)
                        .padding().background(Color(UIColor.secondarySystemBackground)).cornerRadius(12).padding(.horizontal, 40)
                        .autocapitalization(.allCharacters).disableAutocorrection(true)
                    
                    Button(action: activateCode) {
                        HStack {
                            if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            else { Text("تفعيل المتجر").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12).padding(.horizontal, 40)
                    }
                    .disabled(codeInput.isEmpty || isLoading)
                }
                if let error = authManager.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote).multilineTextAlignment(.center).padding(.horizontal)
                }
                Spacer()
                Button("شراء كود تفعيل؟") { if let url = URL(string: "https://t.me/your_telegram_channel") { UIApplication.shared.open(url) } }
                    .foregroundColor(.blue).padding(.bottom, 30)
            }
        }
        .alert(isPresented: $showAlert) { Alert(title: Text("تنبيه"), message: Text(alertMessage), dismissButton: .default(Text("حسناً"))) }
    }
    
    private func activateCode() {
        isLoading = true
        authManager.verifyCodeFromServer(code: codeInput) { success, message in
            isLoading = false
            if !success { self.alertMessage = message ?? "حدث خطأ غير معروف."; self.showAlert = true }
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
                    // ❌ تم إزالة إشعار التوقيع القديم البطيء من هنا
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
    
    // 🔥 دالة الربط المباشر الصاروخية للتوقيع (بدون أي تأخير)
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
                // في كل الأحوال، عند انتهاء التوقيع أو فشله، يجب إخفاء شريط التحميل/التوقيع
                DownloadManager.shared.removeDownload(id: downloadId)
                
                if let error = error {
                    UIAlertController.showAlertWithOk(title: "فشل التوقيع التلقائي", message: error.localizedDescription)
                } else {
                    if options.post_deleteAppAfterSigned { Storage.shared.deleteApp(for: latestApp) }
                    // إطلاق نافذة التثبيت فوراً للمشترك
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
                FR.handleCertificateFiles(p12URL: p12Url, provisionURL: provisionURL, p12Password: password, certificateName: certName, isDefault: true) { _ in }
            }
            UserDefaults.standard.set(true, forKey: "systore.didImportDefaultCertificates")
        } catch { Logger.misc.error("Failed to list signing-assets: \(error)") }
    }
}

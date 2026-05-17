//
//  SettingsView.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - جلب الرقم المصنعي الدقيق للجهاز
extension UIDevice {
    var exactModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - View
struct SettingsView: View {
    @AppStorage("systore.selectedCert") private var _storedSelectedCert: Int = 0
    
    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>
    
    private var selectedCertificate: CertificatePair? {
        guard _storedSelectedCert >= 0, _storedSelectedCert < _certificates.count else { return nil }
        return _certificates[_storedSelectedCert]
    }

    var body: some View {
        NBNavigationView("الإعدادات") {
            Form {
                _aboutSection()
                
                // 🔥 قسم معلومات التفعيل بألوان التطبيق المتناسقة
                Section {
                    NavigationLink(destination: ActivationInfoView()) {
                        Label("معلومات التفعيل", systemImage: "person.text.rectangle.fill")
                            .foregroundColor(.accentColor)
                    }
                } footer: {
                    Text("عرض تفاصيل الاشتراك والكود ومعرف الجهاز.")
                }
                
                Section {
                    NavigationLink(destination: AppearanceView()) {
                        Label("المظهر", systemImage: "paintbrush")
                    }
                }
                
                NBSection("الشهادات") {
                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text("لا توجد شهادة")
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }
                    NavigationLink(destination: CertificatesView()) {
                        Label("الشهادات", systemImage: "checkmark.seal")
                    }
                } footer: {
                    Text("أضف وأدر الشهادات المستخدمة لتوقيع التطبيقات.")
                }
                
                NBSection("الميزات") {
                    NavigationLink(destination: ConfigurationView()) {
                        Label("خيارات التوقيع", systemImage: "signature")
                    }
                    NavigationLink(destination: InstallationView()) {
                        Label("التثبيت", systemImage: "arrow.down.circle")
                    }
                } footer: {
                    Text("تكوين طريقة التثبيت والتعديلات المخصصة على التطبيقات.")
                }
                
                Section {
                    NavigationLink(destination: ResetView()) {
                        Label("إعادة تعيين", systemImage: "trash")
                    }
                } footer: {
                    Text("إعادة تعيين الشهادات والتطبيقات والمحتويات العامة.")
                }
            }
        }
    }
}

extension SettingsView {
    @ViewBuilder
    private func _aboutSection() -> some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Label {
                    Text("حول التطبيق")
                } icon: {
                    AsyncImage(url: URL(string: "https://up6.cc/2026/05/177886610803681.jpeg")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if phase.error != nil {
                            Image(systemName: "info.circle.fill").resizable().frame(width: 26, height: 26).foregroundColor(.gray)
                        } else {
                            ProgressView().frame(width: 26, height: 26)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - شاشة معلومات التفعيل (ActivationInfoView)
struct ActivationInfoView: View {
    @AppStorage("activation_code") private var activationCode: String = "غير متوفر"
    
    let deviceName = UIDevice.current.exactModelName
    let deviceUDID = UIDevice.current.identifierForVendor?.uuidString ?? "غير متوفر"
    
    var body: some View {
        Form {
            Section(header: Text("تفاصيل الاشتراك الحالي")) {
                InfoRow(title: "كود التفعيل", value: activationCode.uppercased())
                InfoRow(title: "طراز الجهاز الدقيق", value: deviceName)
                InfoRow(title: "المعرف البرمجي (IDFV)", value: deviceUDID)
            }
            
            Section {
                Button(action: {
                    UIPasteboard.general.string = deviceUDID
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.accentColor)
                        Text("نسخ المعرف البرمجي")
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
            } footer: {
                Text("تنبيه: نظام iOS يمنع التطبيقات من قراءة الـ UDID الحقيقي لدواعي أمنية. المعرف الموضح أعلاه هو (IDFV) وهو المعتمد لحماية اشتراكك في المتجر.")
            }
        }
        .navigationTitle("معلومات التفعيل")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.body).fontWeight(.semibold).textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

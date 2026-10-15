import SwiftUI

enum LegalLinks {
    static let supportEmail = "kaunosgames@gmail.com"
    static let privacyURL = URL(string: "https://github.com/Gokalpkg/kirmatas/blob/main/PRIVACY_POLICY.md")!

    static var mailURL: URL {
        URL(string: "mailto:\(supportEmail)?subject=Kirmatas%20Support")!
    }
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    private var turkish: Bool { I18n.currentLang == "tr" }

    var body: some View {
        ZStack {
            Color(hex: 0xFF101320).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(I18n.tr("privacy_policy"))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFFFFD54F))
                        Spacer()
                        Button(I18n.tr("close")) { dismiss() }
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text("Kaunos Games  ·  kaunosgames@gmail.com")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(turkish ? "Yürürlük: 18 Eylül 2026" : "Effective: 18 September 2026")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))

                    legalBlock(
                        title: turkish ? "Kim işliyor" : "Who operates this app",
                        body: turkish
                            ? "Kırmataş, Kaunos Games tarafından sunulur. Hesap oluşturmazsın. Skor, altın ve ayarlar yalnızca cihazında saklanır."
                            : "Kirmatas is operated by Kaunos Games. There is no account. Scores, gold, and settings stay on your device."
                    )
                    legalBlock(
                        title: turkish ? "Toplanan veriler" : "Data we collect",
                        body: turkish
                            ? "Reklamlar Google AdMob ile gösterilir. İzin verirsen reklam kimliği (IDFA) kişiselleştirilmiş reklam için kullanılabilir. İzni reddedersen oyun oynamaya devam eder. Uygulama IP, cihaz türü ve reklam etkileşimi gibi teknik verileri Google’ın kendi politikasına göre işleyebilir."
                            : "Ads are shown with Google AdMob. If you allow tracking, the advertising identifier may be used for personalized ads. If you decline, you can still play. Google may process technical data such as IP address, device type, and ad interactions under its own policy."
                    )
                    legalBlock(
                        title: turkish ? "Çocuklar" : "Children",
                        body: turkish
                            ? "Uygulama 13 yaşın altındaki çocuklara yönelik değildir. Böyle bir veri fark edilirse silinmesi için kaunosgames@gmail.com adresine yaz."
                            : "The app is not directed at children under 13. If you believe a child sent personal data, email kaunosgames@gmail.com and it will be deleted."
                    )
                    legalBlock(
                        title: turkish ? "Silme ve hakların" : "Deletion and your rights",
                        body: turkish
                            ? "Cihazındaki kayıtları silmek için uygulamayı kaldırabilirsin. Kaunos Games’in veya reklam ortağının tuttuğu verinin silinmesini, düzeltilmesini ya da erişimini istemek için kaunosgames@gmail.com adresine yaz."
                            : "Uninstalling the app removes the save stored on the device. To request access, correction, or deletion of data held by Kaunos Games or its ad partner, email kaunosgames@gmail.com."
                    )
                    legalBlock(
                        title: turkish ? "Kullanım şartları" : "Terms",
                        body: turkish
                            ? "Uygulamayı kişisel kullanım için indirebilirsin. Kodu kopyalamak, tersine mühendislik yapmak ve markayı izinsiz kullanmak yasaktır. İnternet bağlantısı reklamlar için gerekebilir; bağlantı ücretinden operatörün sorumludur. Tüketici hukukunun emredici hakları saklıdır."
                            : "You may install the app for personal use. Copying the code, reverse engineering, and using the brand without permission are not allowed. Ads may need an internet connection; your carrier’s data charges still apply. Mandatory consumer rights stay in force."
                    )

                    Button {
                        UIApplication.shared.open(LegalLinks.privacyURL)
                    } label: {
                        Label(turkish ? "Tam metin (GitHub)" : "Full text (GitHub)", systemImage: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0xFF00E5FF))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(24)
            }
        }
    }

    private func legalBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

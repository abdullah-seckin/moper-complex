import 'package:flutter/material.dart';

class LegalTextPage extends StatelessWidget {
  const LegalTextPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  static const kvkkBody = '''
Moper Complex, personel giriş ve çıkış doğrulaması için kullanıcı kimliği, işlem zamanı, QR doğrulama sonucu, cihaz bilgisi ve konum verisini işler.

Bu veriler yalnızca iş yeri devam kontrolü, güvenlik doğrulaması, raporlama ve yetkili IK/admin kullanıcılarının denetim süreçleri için kullanılır.

Konum verisi sadece QR okutma anında alınır. Uygulama arka planda sürekli konum takibi yapmaz.

Yetkili kullanıcılar kişisel verilere yalnızca görevleri kapsamında erişir. Demo ve portfolio kurulumlarında gerçek üretim verileri yerine örnek veri kullanılması önerilir.
''';

  static const consentBody = '''
QR kod okutarak giriş/çıkış işlemi yaptığım sırada konum verimin alınmasına, bu verinin işlem zamanı ve kullanıcı hesabımla birlikte devam kontrolü amacıyla işlenmesine açık rıza veriyorum.

Konum izni vermediğim durumda giriş/çıkış doğrulama işleminin tamamlanamayacağını biliyorum.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

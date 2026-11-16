import 'package:flutter/material.dart';
import '../services/varnix_appearance.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = VarnixAppearance.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('شخصی‌سازی ظاهر وارنیکس')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(context, 'رنگ برنامه', 'یکی از رنگ‌های اصلی دلخواهت را انتخاب کن.'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: VarnixAppearance.palettes.entries.map((entry) {
                  final selected = appearance.paletteName == entry.key;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => appearance.setPalette(entry.key),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? entry.value : Colors.white12, width: selected ? 2 : 1),
                      ),
                      child: Column(children: [
                        CircleAvatar(backgroundColor: entry.value, radius: 17, child: selected ? const Icon(Icons.check, color: Colors.white) : null),
                        const SizedBox(height: 7),
                        Text(entry.key, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'فونت نوشته‌ها', 'فونت‌های موجود روی گوشی استفاده می‌شوند؛ نیازی به دانلود ندارند.'),
              DropdownButtonFormField<String>(
                value: appearance.fontName,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'انتخاب فونت'),
                items: VarnixAppearance.fonts.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (value) { if (value != null) appearance.setFont(value); },
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'اندازه نوشته‌ها', 'برای خوانایی بهتر، اندازه متن را تنظیم کن.'),
              Row(children: [
                const Text('کوچک'),
                Expanded(child: Slider(
                  value: appearance.textScale,
                  min: .85,
                  max: 1.25,
                  divisions: 8,
                  label: '${(appearance.textScale * 100).round()}٪',
                  onChanged: appearance.setTextScale,
                )),
                const Text('بزرگ'),
              ]),
              Center(child: Text('پیش‌نمایش متن وارنیکس', style: TextStyle(fontSize: 16 * appearance.textScale, fontWeight: FontWeight.bold))),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('چیدمان فشرده'),
                subtitle: const Text('فاصله بین اجزای رابط کاربری کمتر شود.'),
                value: appearance.compact,
                onChanged: appearance.setCompact,
              ),
              const SizedBox(height: 12),
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.palette_outlined, color: appearance.seed),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('انتخاب‌ها روی همین دستگاه ذخیره می‌شوند و با باز کردن دوباره برنامه باقی می‌مانند.')),
                ]),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
    ]),
  );
}

// ============================================================================
// main.dart — «Девор» (Devor)
// Бозори 100% ройгони эълонҳо барои Тоҷикистон
// UX/Design модели Divar (divar.ir), локализатсияи 100% тоҷикӣ (Кириллӣ), LTR.
//
// Архитектура:
//  • 5-Tab Bottom Navigation: Эълонҳо | Бандҳо | Сабти эълон | Чат | Девори ман
//  • 0 network image — ҳамаи тасвирҳо GradientArt (CustomPaint/icon) офарида мешаванд
//  • Қабати амният: security_auth_service.dart (lockout, OTP, masking, logout wipe)
//  • SUPER-ADMIN GATE (5-tap на логотип): Zero-Exposure Owner-Defined Credentials
//  • UNLIMITED LIVE BUILDER: unlimited_app_schema_controller.dart
//      — шаҳрҳо/маҳаллаҳо, бандҳо/зербандҳо/брендҳо, фаслҳо/реҷаҳо/филтрҳои
//        динамикӣ, иконка/рангҳо/bannerҳо — бемаҳдуд + Instant OTA Publish
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/security_auth_service.dart';
import 'services/unlimited_app_schema_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DevorApp());
}

/// SSL Certificate Pinning + HTTPS-only transport guard (SECURITY.md).
/// Дар барномаи воқеӣ: dio + badCertificateCallback бо pin SPKI-Base64,
/// ки pin-ҳо аз сервер ба таври дурнамо гирифта мешаванд (не hardcode дар client).
class TransportGuard {
  static const String pinnedSha256Fingerprint =
      'sha256/REPLACE_WITH_SERVER_SPKI_PIN'; // аз CI/CD inject мешавад

  static bool verify(Uri url) {
    if (url.scheme != 'https') {
      throw StateError('Танҳо HTTPS иҷозат дода шудааст (cleartext blocked).');
    }
    return true;
  }
}

// ============================ ПАЛЛИАИ РАНГ (Divar tokens) ============================
class C {
  static const brand = Color(0xFFA62626);
  static const brandHover = Color(0xFF8E1F1F);
  static const brandDark = Color(0xFFD94141);
  static const bgLight = Colors.white;
  static const surfaceLight = Color(0xFFF5F5F5);
  static const hoverLight = Color(0xFFFAFAFA);
  static const hairline = Color(0xFFE6E6E6);
  static const textDark = Color(0xFF212121);
  static const textMid = Color(0xFF707070);
  static const textMuted = Color(0xFF9E9E9E);
  static const success = Color(0xFF1B873F);
  static const bgDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const borderDark = Color(0xFF2E2E2E);
  static const textDarkMode = Color(0xFFF1F1F1);
  static const textDarkMid = Color(0xFFA0A0A0);
}

class Palette {
  final bool dark;
  const Palette(this.dark);
  Color get bg => dark ? C.bgDark : C.bgLight;
  Color get surface => dark ? C.surfaceDark : C.surfaceLight;
  Color get hairline => dark ? C.borderDark : C.hairline;
  Color get text => dark ? C.textDarkMode : C.textDark;
  Color get textMid => dark ? C.textDarkMid : C.textMid;
  Color get muted => dark ? C.textDarkMid : C.textMuted;
  Color get brand => dark ? C.brandDark : C.brand;
}

/// Ранг аз hex-string ('#A62626') — барои schema-и динамикӣ
Color colorFromHex(String hex, [Color fallback = C.brand]) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v != null ? Color(v) : fallback;
}

// ============================ APP ROOT ============================
class DevorApp extends StatefulWidget {
  const DevorApp({super.key});
  @override
  State<DevorApp> createState() => _DevorAppState();
}

class _DevorAppState extends State<DevorApp> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: C.brand,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(primary: dark ? C.brandDark : C.brand, secondary: C.success);

    return MaterialApp(
      title: 'Девор — Эълонҳои Тоҷикистон',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(scheme, false),
      darkTheme: _theme(scheme, true),
      home: RootShell(onToggleTheme: () => setState(() => dark = !dark), isDark: dark),
    );
  }

  ThemeData _theme(ColorScheme s, bool d) {
    final p = Palette(d);
    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.text),
        titleTextStyle: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      dividerColor: p.hairline,
      cardTheme: CardThemeData(
        color: p.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: p.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        labelStyle: TextStyle(color: p.text, fontSize: 13),
        side: BorderSide(color: p.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: d ? C.surfaceDark : C.textDark,
        contentTextStyle: TextStyle(color: d ? C.textDarkMode : Colors.white),
      ),
    );
  }
}

// ============================ МОДЕЛҲО ============================
class Ad {
  final String id, title, catPath, district, city, specs, timeAgo, condition;
  final int? price; // null => Ройгон
  final bool negotiable, exchange, urgent;
  final IconData icon;
  final List<Color> artColors;
  final Map<String, String> specsTable;
  final String description, phone, seller;
  final int photos;
  Ad({
    required this.id, required this.title, required this.catPath, required this.district,
    required this.city, required this.specs, required this.timeAgo, required this.condition,
    required this.price, required this.icon, required this.artColors,
    required this.specsTable, required this.description, required this.phone,
    required this.seller, this.negotiable = false, this.exchange = false,
    this.urgent = false, this.photos = 3,
  });
}

class ChatMsg {
  final String text;
  final bool me;
  final DateTime at;
  ChatMsg(this.text, {required this.me}) : at = DateTime.now();
}

class Conversation {
  final Ad ad;
  final String seller;
  final List<ChatMsg> msgs;
  int unread;
  Conversation(this.ad, this.seller, {List<ChatMsg>? msgs, this.unread = 0})
      : msgs = msgs ?? [];
}

// ============================ МАЪЛУМОТИ (SEED) ============================
/// 30 эълони воқеӣ (catPath-ҳо бо schema-и пешфарз мувофиқанд)
List<Ad> seedAds() {
  const car = [Color(0xFFB0BEC5), Color(0xFF78909C)];
  const home = [Color(0xFFFFCC80), Color(0xFFFFB74D)];
  const phoneC = [Color(0xFF90CAF9), Color(0xFF64B5F6)];
  const pc = [Color(0xFFA5D6A7), Color(0xFF81C784)];
  const kid = [Color(0xFFF48FB1), Color(0xFFF06292)];
  const cloth = [Color(0xFFCE93D8), Color(0xFFBA68C8)];
  const pet = [Color(0xFFFFAB91), Color(0xFFFF8A65)];
  const job = [Color(0xFF80DEEA), Color(0xFF4DD0E1)];
  const build = [Color(0xFFE0E0E0), Color(0xFFBDBDBD)];
  const other = [Color(0xFFFFF59D), Color(0xFFFFEE58)];
  var n = 0;
  Ad mk(String t, String cp, String sp, int? pr, String cond, IconData ic, List<Color> col,
      Map<String,String> st, String desc, String ph, String sell, String dist,
      {bool neg = false, bool ex = false, bool urg = false, int phs = 3}) {
    return Ad(
      id: 'ad${++n}', title: t, catPath: cp, district: dist, city: 'Душанбе',
      specs: sp, timeAgo: '${(n * 7 % 59) + 2} дақиқа пеш', condition: cond, price: pr,
      icon: ic, artColors: col, specsTable: st, description: desc, phone: ph,
      seller: sell, negotiable: neg, exchange: ex, urgent: urg, photos: phs,
    );
  }
  return [
    mk('Хонаи 2-хонагӣ дар маркази Душанбе', 'Амволи ғайриманқул / Фурӯши хонаҳо / 2-хонагӣ',
        '2-хонагӣ, 71 м², 10 ошёна', 106500000, 'Омода барои зиндагӣ', Icons.home,
        home, {'Хонаҳо':'2','Масоҳат':'71 м²','Ошёна':'10','Масолеҳ':'Монолит','Гармидиҳӣ':'Ҳаст','Сол':'2021'},
        'Хонаи нав дар кӯчаи Рӯдакӣ, воҳиди тамоми таъмиршуда, бо диди зебо. Ҳуҷраҳои ҷудошуда, балкони калон, лифт дар кор. Наздик: мактаб №1, бозори Корвон, боғчаи Фирдавсӣ.', '+992 90 123 45 67', 'Фаридун Р.', 'Сомонӣ', photos: 8),
    mk('Toyota Camry 2023, як соҳиб', 'Нақлиёт / Автомобили сабукрав / Toyota',
        'Автомат • Бензин • 2023', 235000000, 'Ҳолати хуб', Icons.directions_car,
        car, {'Тамға':'Toyota','Модел':'Camry','Сол':'2023','Кузов':'Седан','Қуттӣ':'Автоматикӣ','Сӯзишворӣ':'Бензин','Давидан':'45 000 км'},
        'Мошини тамоми таъмир, як соҳиб, аз дукуша. Тозагӣ дар кор, камераи баргарданд, ҳавоназори дучандагӣ. Ба мубодила бо Toyota Land Cruiser ба ҳисоби фарқ мекунам.', '+992 93 222 11 00', 'Далер Ш.', 'Исмоили Сомонӣ', neg: true, ex: true, photos: 6),
    mk('iPhone 15 Pro 256GB — нав', 'Телефонҳо ва алоқа / Телефонҳои мобилӣ / Apple',
        'Нав • IMEI санҷидашуда', 9800000, 'Нав', Icons.phone_iphone,
        phoneC, {'Тамға':'Apple','Модел':'iPhone 15 Pro','Хотира':'256 GB','Ранг':'Титан-кабуд','Ҳолат':'Нав','IMEEI':'Санҷидашуда'},
        'Расман аз ОАЕ, плёнкаи заводӣ, аксорӣ ва гӯшмонак дар қуттӣ. Талаб мекунам санҷиш дар дукон — IMEI дар сафҳаи Apple актив.', '+992 55 400 30 20', 'Сино А.', 'Профсоюз', photos: 5),
    mk('Ноутбук Lenovo IdeaPad 5, Ryzen 7', 'Компютерҳо ва таҷҳизоти идоравӣ / Ноутбукҳо',
        'Ryzen 7, 16GB, 512GB SSD', 5400000, 'Дар ҳолати хуб', Icons.laptop_mac,
        pc, {'Процессор':'Ryzen 7 5700U','RAM':'16 GB','Диск':'512 GB SSD','Экран':'15.6" IPS','Ҳолат':'Истифодашуда, 8/10'},
        'Барои кор ва таҳсил комил. Батарея 6 соат. Гарантияи дукон боқӣ — 4 моҳ. Барои фӯтушоп ва барномасозӣ бас.', '+992 91 555 44 33', 'Умед Т.', 'Зарафшон', photos: 4),
    mk('Кӯрпаи нав — мубодила бо велосипеди кӯдакона', 'Ройгон медиҳам / Дигар молҳои ройгон',
        'Мубодила • Ҳолати нав', null, 'Нав', Icons.swap_horiz,
        other, {'Навъ':'Мубодила','Ҳолат':'Нав'},
        'Кӯрпаи нав ба роҳ намеравад — мубодила бо велосипеди кӯдакона ё бозичаҳо. Ҳама чиз тоза ва тавсия мешавад!', '+992 50 777 66 55', 'Мадина Ю.', '82 мкр', ex: true, photos: 2),
    mk('Маош: Ошпаз — ресторани «Иқбол»', 'Ҷои кор / Рестораторҳо, ошпазҳо, пешхизматҳо',
        'Маош: 4 500 с. • Рӯзона', null, 'Тамом-вақт', Icons.restaurant,
        job, {'Маош':'4 500 с.','Реҷа':'Рӯзона','Таҷриба':'аз 2 сол','Меҳнати':'Дар ҷой'},
        'Ресторани хонадории «Иқбол» дар бозори Садбарг ба ошпаз маллоҳ корӣ кардани. Обид ба реҷа, медикӣ, хӯрокворӣ дар ҳисоби кор.', '+992 88 111 22 33', 'ХР «Иқбол»', 'Садбарг', photos: 3),
    mk('Панҷараи мошин — шинаи зим, 4 дона', 'Нақлиёт / Лавозимот ва қисмҳои нақлиёт / Шина ва дискаҳо',
        'R16, зим', 1200000, 'Дар ҳолати хуб', Icons.tire_repair,
        build, {'Шино':'Зим','Андоза':'R16','Микдор':'4 дона','Ҳолат':'70% профил'},
        'Шинаҳои зим барои зимистон — R16, ягон мавсум истифода шуда. Ба Camry/Opel/Astra мутобиқ.', '+992 92 000 11 22', 'Шамс Ҳ.', '33 мкр', photos: 3),
    mk('Samsung Galaxy S23 Ultra 512GB', 'Телефонҳо ва алоқа / Телефонҳои мобилӣ / Samsung',
        'Дар ҳолати хуб • IMEI санҷидашуда', 7900000, 'Дар ҳолати хуб', Icons.smartphone,
        phoneC, {'Тамға':'Samsung','Модел':'S23 Ultra','Хотира':'512 GB','Батарея':'95%','IMEEI':'Санҷидашуда'},
        'Ҳолати 9.5/10, плёнка аз рӯзи аввал, ду ҳиссаи камерааҳо тоза. Баргардани 20% бо мубодила бо iPhone 14 Pro.', '+992 99 333 44 55', 'Шоҳина К.', 'Фирдавсӣ', neg: true, ex: true, photos: 5),
    mk('Гаҳвораи нав бо матраси ортопедӣ', 'Олами кӯдакон / Мебели кӯдакона / Гаҳвораҳо',
        'Нав', 1450000, 'Нав', Icons.crib,
        kid, {'Навъ':'Гаҳвора','Масолеҳ':'Чӯби сӯзан','Матрас':'Ортопедӣ','Ҳолат':'Нав'},
        'Гаҳвораи нав — туҳфа буд, лекин имконати ҳоҷат набуд. Дар Ҳисор бурдан мумкин.', '+992 90 888 77 66', 'Нурия Ҷ.', 'Марказ', photos: 4),
    mk('Ҳавлии 3-ошёна бо замин — 6 сотих', 'Амволи ғайриманқул / Фурӯши ҳавлӣ ва дача',
        '6 сотих, 120 м²', 42000000, 'Омода', Icons.house,
        home, {'Замин':'6 сотих','Хона':'120 м²','Ошёна':'3','Масолеҳ':'Хишт','Об/Газ':'Ҳаст'},
        'Ҳавлӣ дар нобои Душанбе, чор маълӣ сохта, боғи меваҳо, гараж. Хуҷатҳо омода, боқӣ ҷараёни сотия.', '+992 48 555 12 34', 'Абдулло С.', 'Ҳисор', urgent: true, photos: 7),
    mk('БМВ 320i 2019 — тамоми таъмир', 'Нақлиёт / Автомобили сабукрав / BMW',
        'Автомат • Бензин • 2019', 189000000, 'Ҳолати хуб', Icons.directions_car,
        car, {'Тамға':'BMW','Модел':'320i','Сол':'2019','Кузов':'Седан','Қуттӣ':'Автоматикӣ','Сӯзишворӣ':'Бензин'},
        'Мошини немецӣ — тамоми таъмир, камера 360, салон тоза. Суғурта боқӣ. Баргардан каме аз нарх — ба воситаи мубодила бо Mercedes C-Class.', '+992 93 999 88 77', 'Рустам Ғ.', 'Сино', neg: true, photos: 6),
    mk('Пушаки хушзот — муфт', 'Ҳайвонот ва растаниҳо / Пушакҳо',
        '2 моҳагӣ • Ба пӯрӣ', null, 'Ройгон', Icons.pets,
        pet, {'Навъ':'Пушак','Сол':'2 моҳ','Ҷинс':'Хушзот','Ваксина':'Нафишонда'},
        'Пушакҳои муфт ба дастҳои хуш ба монанди беҳатарӣ мидиҳам. Хӯроккунии комил, ҷойҳои хомӯшӣ мумкин.', '+992 55 222 33 44', 'Тахмина Д.', 'Шоҳмансур', photos: 3),
    mk('Корманд: савдоги дар дукон', 'Ҷои кор / Тиҷорат, савдои чакана',
        'Маош: 2 800 с. • Реҷаи озод', null, 'Тамом-вақт', Icons.storefront,
        job, {'Маош':'2 800 с. + бонус','Реҷа':'Реҷаи озод','Таҷриба':'Бе таҷриба'},
        'Дукони электроника дар шаҳри Душанбе ба савдоги маллоҳ карда мешавад. Бо ташаббуси ошкор', '+992 88 555 66 77', 'Баҳоӣ Э.', 'Исмоили Сомонӣ', photos: 2),
    mk('Духтари XIAOMI Mi Electric Scooter 4', 'Нақлиёт / Дигар нақлиёт / Гироскутерҳо',
        'Электр • 25 км/соат', 2200000, 'Дар ҳолати хуб', Icons.electric_scooter,
        other, {'Тамға':'Xiaomi','Модел':'Scooter 4','Сӯзишворӣ':'Электр','Ҳолат':'7/10'},
        'Самокати электрӣ — 25 км/соат, батарея 30 км. Аксорӣ боқӣ.', '+992 90 444 55 66', 'Алиҷон М.', 'Профсоюз', ex: true, photos: 4),
    mk('Мебели ошхона — миз + 6 курсӣ', 'Барои манзил / Мебел',
        'Чӯби табиӣ', 3800000, 'Дар ҳолати хуб', Icons.table_restaurant,
        other, {'Масолеҳ':'Чӯби табиӣ','Микдор':'Миз + 6 курсӣ','Ранг':'Қаҳваранг'},
        'Мебели ошхонаи табии чӯбӣ — тамоми таъмир. Ташхис дар ҷой мумкин.', '+992 92 666 77 88', 'Гулназ Р.', 'Зарафшон', neg: true, photos: 5),
    mk('Тросс боркаш — МАЗ 54323', 'Нақлиёт / Нақлиёти тиҷоратӣ / Нақлиёти боркаш',
        'Дизел • 2015', 145000000, 'Ҳолати хуб', Icons.local_shipping,
        car, {'Тамға':'МАЗ','Модел':'54323','Сол':'2015','Сӯзишворӣ':'Дизел','Юк':'20 тонна'},
        'Мошинаи боркаши тайёр — контейнери металлӣ, тамоми таъмир. Дар кор ҳар рӯз.', '+992 48 777 88 99', 'Карим Н.', 'Турсунзода', photos: 4),
    mk('Атриёти занона — либосҳои ортензӣ', 'Либос ва ашёҳои шахсӣ / Атриёт ва косметика',
        'Нав', 350000, 'Нав', Icons.checkroom,
        cloth, {'Навъ':'Либосҳо','Микдор':'12 дона','Ҳолат':'Нав'},
        'Партияи нави либосҳои ортензӣ аз истеҳсоли Душанбе — нархи ягона.', '+992 90 333 22 11', 'Зулфия Х.', 'Фирдавсӣ', photos: 6),
    mk('PS5 Slim бозӣ аз хона берун', 'Компютерҳо ва таҷҳизоти идоравӣ / Дастгоҳи бозикунӣ',
        'Нав • 1TB', 6500000, 'Нав', Icons.videogame_asset,
        pc, {'Тамға':'Sony','Модел':'PS5 Slim','Хотира':'1TB','Диск':'Сонӣ ё Digital'},
        'Плейстейшн 5 Slim — нав, аз Ҷопонӣ. 2 geym pad ба боқӣ. Ба мубодила бо Switch OLED.', '+992 99 111 22 33', 'Эмомалӣ Ҷ.', '82 мкр', ex: true, photos: 3),
    mk('Хонаи нав дар Навсохти «Душанбе-Сити»', 'Навсохтҳо / Навсохтҳои дар ҷараёни сохтмон',
        '2-хонагӣ, 64 м², 7 ошёна', 68000000, 'Дар ҷараёни сохтмон', Icons.apartment,
        home, {'Хонаҳо':'2','Масоҳат':'64 м²','Ошёна':'7','Масолеҳ':'Монолит','Насия':'Ҳаст','Тахмин':'12.2026'},
        'ЖК «Душанбе-Сити» — хонаи нав дар пешбурд. Насия 24 моҳ бе фоиз, аванс 30%.', '+992 50 888 99 00', 'НК «Сомон-Сити»', 'Исмоили Сомонӣ', photos: 5),
    mk('Услуги: таъмири мошин дар ҷой', 'Хизматрасониҳо / Таъмир ва сохтмон',
        '24/7', null, 'Хизмат', Icons.build,
        build, {'Навъ':'Хизмат','Соатҳо':'24/7','Ноҳия':'Душанбе'},
        'Мошина баргардонида мешавад дар ҷой — электрик, саркаши, асоӣ. Ҳисоби шаффоф.', '+992 93 123 65 43', 'Саида Ф.', 'Сино', photos: 2),
    mk('Курсии кӯдакона барои мошин — 0+12', 'Олами кӯдакон / Курсии кӯдакона барои мошин',
        'Нав • 0-12 сол', 900000, 'Нав', Icons.child_friendly,
        kid, {'Гурӯҳ':'0+/1/2/3','Ҳолат':'Нав','Сертификат':'Ҳаст'},
        'Курсии имнӣ барои мошин — нав, сертификати EU. Ҳамаат қайшӣ дар кор.', '+992 91 321 65 49', 'Дилноза А.', 'Марказ', photos: 3),
    mk('Оппо A58 128GB — истифодашуда', 'Телефонҳо ва алоқа / Телефонҳои мобилӣ / Oppo',
        'Истифодашуда', 1150000, 'Дар ҳолати хуб', Icons.phone_android,
        phoneC, {'Тамға':'Oppo','Модел':'A58','Хотира':'128 GB','Ҳолат':'8/10','IMEEI':'Санҷидашуда'},
        'Телефони хуш — батарея 5000mAh, камера 50MP. Кейс ва плёнка ба ҳамроҳӣ.', '+992 55 654 32 10', 'Далер Т.', 'Бохтар-марказ', photos: 4),
    mk('Хизмат: такси барои сайёҳат — Сӯғд', 'Хизматрасониҳо / Нақлиёт ва сайёҳат',
        'Сайёҳат', null, 'Хизмат', Icons.local_taxi,
        other, {'Навъ':'Такси','Асса':'То 4 киши','Масофа':'Душанбе — Сӯғд'},
        'Дар воситаи Осиё — ташаҳҳи санъатӣ, соат ва ҳуҷраи хуш.', '+992 92 987 65 43', 'Такси «Сӯғд-Тур»', 'Хуҷанд-марказ', photos: 2),
    mk('Пурсишҳои бузург бо бозӣ — Баим', 'Олами кӯдакон / Бозичаҳо',
        'Нав', 450000, 'Нав', Icons.toys,
        kid, {'Сол':'3-10','Ҳолат':'Нав','Матолеъ':'Пластик имнӣ'},
        'Бозичаҳои бузург бо баргардонида — ба ҳамаат хуш омадаид!', '+992 90 999 11 22', 'Насрин Ҷ.', 'Садбарг', photos: 3),
    mk('Хонаи якшабонарӯза дар Панҷакент', 'Амволи ғайриманқул / Иҷораи якшабонарӯзаи хона, ҳавлӣ',
        '1 шабона — 350 с.', 3500000, 'Омода', Icons.cabin,
        home, {'Хонаҳо':'3','Масоҳат':'110 м²','Об/Гарм':'Ҳаст','Wi-Fi':'Ҳаст'},
        'Хонаи тайёр барои якшабонарӯза бо сауна ва ҳавзи шино — бо тӯйҳо ва ҷашнҳо мувофиқ.', '+992 48 654 98 76', 'Бахтиёр И.', 'Панҷакент', photos: 6),
    mk('Мерседес-Бенс C180 2020', 'Нақлиёт / Автомобили сабукрав / Mercedes-Benz',
        'Автомат • Бензин • 2020', 215000000, 'Ҳолати хуб', Icons.directions_car,
        car, {'Тамға':'Mercedes-Benz','Модел':'C180','Сол':'2020','Кузов':'Седан','Қуттӣ':'Автоматикӣ'},
        'Ҳолати хеле хуш — як соҳиб, таъмир аз дилер. Тозагӣ ҳар ҳафта. Фақат Сӯғдд!', '+992 93 456 78 90', 'Иброҳим К.', 'Хуҷанд-марказ', neg: true, photos: 7),
    mk('Дастгоҳи дарворӣ — асоӣ ва зуд', 'Хизматрасониҳо / Ороиш ва либосшӯй',
        'Нав', 500000, 'Хизмат', Icons.cut,
        cloth, {'Навъ':'Хизмат','Замина':'Дар дукон','Соат':'9:00-20:00'},
        'Дарворӣ ва либосшӯй — таъмини 24 соат, дукон дар бозори Садбарг.', '+992 55 789 12 34', 'Кодир Ҷ.', 'Садбарг', photos: 2),
    mk('Столни бозиҳо — шахсӣ ва фанӣ', 'Шавқу завқ, мусиқӣ ва варзиш / Варзиш',
        'Дар ҳолати хуб', 1800000, 'Дар ҳолати хуб', Icons.sports_tennis,
        other, {'Навъ':'Столни бозӣ','Андоза':'Стандарт','Ҳолат':'8/10'},
        'Столни бозӣ — 2 ракеткаи кумӣ. Ба ҳамроҳӣ бо шарҳои аз боло.', '+992 50 222 44 66', 'Манучеҳр Ғ.', '33 мкр', photos: 4),
    mk('Маош: муҳосиб — бонки мобӣ', 'Ҷои кор / Ҳисобдорӣ, молия, ҳуқуқшиносҳо',
        'Маош: 6 500 с. • Рӯзона', null, 'Тамом-вақт', Icons.account_balance,
        job, {'Маош':'6 500 с.','Реҷа':'Рӯзона','Таҷриба':'аз 3 сол','Таҳсил':'Олимон'},
        'Бонки мобӣ ба муҳосиб бо таҷрибаз 3 сол маллоҳ корӣ мекунад. 1С: Бухгалтерӣ ва Excel — муҳим.', '+992 88 345 67 89', 'Бонк «Арванд»', 'Исмоили Сомонӣ', photos: 1),
    mk('Таги бузург — 50 кг', 'Барои тиҷорат / Стиролҳо ва тагҳо',
        'Нав • 50 кг', 120000, 'Нав', Icons.inventory_2,
        build, {'Вазн':'50 кг','Ҳолат':'Нав','Микдор':'10 дона'},
        'Таги нави 50 кг — барои молҳо ва ҷой.', '+992 92 111 33 55', 'Тиҷорат «Ваҳдат»', 'Ваҳдат', photos: 2),
  ];
}

// ============================ ROOT SHELL (5 Tab) ============================
class RootShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const RootShell({super.key, required this.onToggleTheme, required this.isDark});
  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  int tab = 0;
  String city = 'Душанбе';
  List<Ad> ads = seedAds();
  final Set<String> bookmarks = {};
  final List<String> recentlyViewed = [];
  final List<Conversation> conversations = [];
  final ValueNotifier<int> unreadTotal = ValueNotifier(0);
  Ad? openDetail;
  ListNotifier myAds = ListNotifier();

  /// Муҳаррики Live Schema — ҳамаи шаҳрҳо/бандҳо/филтрҳо/тамошӣ аз ин ҷо
  final UnlimitedAppSchemaController schema = UnlimitedAppSchemaController();

  // — филтрҳои feed —
  String searchQuery = '';
  String? activeCat;
  final Set<String> selectedDistricts = {};
  int? minPrice, maxPrice;
  bool onlyFree = false, onlyPhotos = false, onlyExchange = false, onlyUrgent = false;

  /// Майдонҳои динамикӣ-и интихобшуда (аз Schema) — key → value
  final Map<String, String> dynFilterValues = {};

  List<Ad> get filtered {
    var r = ads.where((a) {
      if (activeCat != null && !a.catPath.startsWith(activeCat!)) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        if (!(a.title.toLowerCase().contains(q) ||
            a.specs.toLowerCase().contains(q) ||
            a.description.toLowerCase().contains(q) ||
            a.district.toLowerCase().contains(q))) return false;
      }
      if (selectedDistricts.isNotEmpty && !selectedDistricts.contains(a.district)) return false;
      if (minPrice != null && (a.price ?? 0) < minPrice!) return false;
      if (maxPrice != null && (a.price ?? 0) > maxPrice!) return false;
      if (onlyFree && a.price != null) return false;
      if (onlyPhotos && a.photos < 2) return false;
      if (onlyExchange && !a.exchange) return false;
      if (onlyUrgent && !a.urgent) return false;
      return true;
    }).toList();
    r.sort((a, b) => a.id.compareTo(b.id));
    return r;
  }

  void openAd(Ad ad) {
    setState(() {
      openDetail = ad;
      if (!recentlyViewed.contains(ad.id)) recentlyViewed.insert(0, ad.id);
      if (recentlyViewed.length > 30) recentlyViewed.removeLast();
    });
  }

  void startChatWith(Ad ad) {
    final existing = conversations.indexWhere((c) => c.ad.id == ad.id);
    if (existing == -1) {
      conversations.insert(0, Conversation(ad, ad.seller, msgs: [
        ChatMsg('Салом! Ман ба эълони «${ad.title}» тавассути Девор навиштам.', me: true),
      ], unread: 0));
    }
    setState(() => tab = 3);
    _recalcUnread();
  }

  void _recalcUnread() => unreadTotal.value = conversations.fold(0, (s, c) => s + c.unread);

  void simulateSellerReply(Conversation c) {
    const replies = [
      'Салом! Ҳа, ҳоло ҳам ҳаст.',
      'Нархи охираш чанд? Барои шумо каме камтар мешавад.',
      'Дар куҷо дидан мумкин? Нозик — ноҳияи Сомонӣ.',
      'Ҳа, метавонед имрӯз соати 18 ба дидан биёед.',
      'Мубодила ҳам мумкин аст, бо чӣ мубодила мешавад?',
    ];
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        c.msgs.add(ChatMsg(replies[c.msgs.length % replies.length], me: false));
        if (tab != 3) c.unread++;
        _recalcUnread();
      });
    });
  }

  // ================================================================
  //  5-TAP SECRET GATE → SUPER-ADMIN (Zero-Exposure Owner Credentials)
  // ================================================================
  void openAdminGate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminGateDialog(shell: this),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: schema,
      builder: (context, _) {
        // Саҳифаҳо ДАРУНИ builder сохта мешаванд — ҳар тағйири schema
        // (шаҳр, банд, филтр, banner, тамошӣ) фавран дар ҳамаи экранҳо
        // инъикос мешавад (Live Builder).
        final pages = [
          HomeTab(shell: this),
          CategoriesTab(shell: this),
          PostWizardTab(shell: this),
          ChatTab(shell: this),
          MyDevorTab(shell: this, onToggleTheme: widget.onToggleTheme),
        ];
        return Scaffold(
        body: Stack(children: [
          IndexedStack(index: tab, children: pages),
          // ===== INSTANT OTA BANNER: «Навсозии нав баромад! • Насб кардан» =====
          if (schema.hasUpdate)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: C.success,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.rocket_launch_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Навсозии нав баромад! v${schema.schemaVersion} — шаҳрҳо, бандҳо ва филтрҳои нав',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.18),
                        ),
                        onPressed: () {
                          schema.applyUpdate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Schema v${schema.schemaVersion} насб шуд ✅')));
                        },
                        child: const Text('Насб кардан', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          if (openDetail != null)
            AdDetailScreen(ad: openDetail!, onClose: () => setState(() => openDetail = null), shell: this),
        ]),
        bottomNavigationBar: _bottomBar(context),
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context) {
    final p = Palette(widget.isDark);
    final items = [
      (Icons.feed_outlined, 'Эълонҳо'),
      (Icons.category_outlined, 'Бандҳо'),
      (Icons.add_circle, 'Сабти эълон'),
      (Icons.chat_bubble_outline, 'Чат'),
      (Icons.person_outline, 'Девори ман'),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: unreadTotal,
      builder: (_, unread, __) => NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.bg,
          indicatorColor: p.brand.withOpacity(0.08),
          height: 64,
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            for (var i = 0; i < items.length; i++)
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: i == 3 && unread > 0,
                  label: Text('$unread'),
                  backgroundColor: C.brand,
                  child: Icon(items[i].$1,
                      color: i == 2 ? p.brand : p.textMid,
                      size: i == 2 ? 30 : 24),
                ),
                label: items[i].$2,
              ),
          ],
        ),
      ),
    );
  }
}

/// Listenable holder барои myAds (post wizard навсозӣ)
class ListNotifier extends ChangeNotifier {
  List<Ad> items = [];
  void add(Ad a) { items.insert(0, a); notifyListeners(); }
  void remove(String id) { items.removeWhere((a) => a.id == id); notifyListeners(); }
}

// ============================ UI: КАРАҲА (Ad Art) ============================
/// Иловаи пурраи офлайн: GradientArt — ҳеҷ network image
class AdArt extends StatelessWidget {
  final Ad ad;
  final bool big;
  const AdArt(this.ad, {super.key, this.big = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: big ? double.infinity : 136,
      height: big ? 220 : 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: ad.artColors,
        ),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _ArtPainter(color: Colors.white.withOpacity(0.18))),
        ),
        Center(child: Icon(ad.icon, size: big ? 64 : 44, color: Colors.white.withOpacity(0.85))),
        if (!big && ad.photos > 1)
          Positioned(
            right: 6, bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.photo_camera_outlined, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text('${ad.photos}', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final Color color;
  _ArtPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), size.width * 0.28, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), size.width * 0.22, paint);
  }
  @override
  bool shouldRepaint(covariant _ArtPainter o) => o.color != color;
}

String priceLabel(Ad a) {
  if (a.price == null) return 'Ройгон';
  final s = a.price.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  var t = '$s с.';
  if (a.negotiable) t += ' • Сӯзишворӣ';
  return t;
}

// ============================ LOGO + 5-TAP GATE ============================
class _DevorLogo extends StatefulWidget {
  final VoidCallback onFiveTaps;
  final UnlimitedAppSchemaController schema;
  const _DevorLogo({required this.onFiveTaps, required this.schema});
  @override
  State<_DevorLogo> createState() => _DevorLogoState();
}

class _DevorLogoState extends State<_DevorLogo> {
  int _taps = 0;
  Timer? _resetTimer;

  static const _emblems = ['🧱', '🏛️', '🛡️', '⚡'];

  void _tap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _taps > 0) setState(() => _taps = 0);
    });
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      widget.onFiveTaps();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.schema.visual;
    final brand = colorFromHex(v.brandColorHex);
    return GestureDetector(
      onTap: _tap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [brand, C.brandHover],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(_emblems[v.logoStyle % _emblems.length],
                style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 8),
        Text(v.appName,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: brand)),
        if (_taps > 0)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: _taps / 5,
                color: brand,
              ),
            ),
          ),
      ]),
    );
  }
}

// ============================ TAB 1: ЭЪЛОНҲО (FEED) ============================
class HomeTab extends StatelessWidget {
  final RootShellState shell;
  const HomeTab({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final p = Palette(shell.widget.isDark);
    return Scaffold(
      appBar: AppBar(
        title: _DevorLogo(schema: shell.schema, onFiveTaps: shell.openAdminGate),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.location_on_outlined, color: p.brand),
            tooltip: shell.city,
            onPressed: () => _pickCity(context),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _SearchHeader(shell: shell, p: p),
          _QuickFilterRibbon(shell: shell, p: p),
          Expanded(child: Stack(children: [
            Column(children: [
              // ===== Bannerҳои динамикӣ аз Schema (админ илова мекунад) =====
              if (shell.schema.visual.banners.isNotEmpty)
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      for (final b in shell.schema.visual.banners)
                        Container(
                          width: 240,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [colorFromHex(b.colorHex), colorFromHex(b.colorHex).withOpacity(0.75)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Text(b.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                if (b.subtitle.isNotEmpty)
                                  Text(b.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5)),
                              ],
                            )),
                          ]),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 560, childAspectRatio: 3.4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: shell.filtered.length,
                    itemBuilder: (_, i) => AdCard(ad: shell.filtered[i], shell: shell, p: p),
                  ),
                ),
              ),
            ]),
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'map',
                backgroundColor: p.brand,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => MapScreen(shell: shell)),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Харита'),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  void _pickCity(BuildContext context) {
    final cities = shell.schema.cityNames;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16),
              child: Text('Интихоби шаҳр', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
          for (final c in cities)
            ListTile(
              leading: Icon(c == shell.city ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: c == shell.city ? C.brand : C.textMuted, size: 20),
              title: Text(c),
              onTap: () {
                shell.setState(() { shell.city = c; shell.selectedDistricts.clear(); });
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final RootShellState shell;
  final Palette p;
  const _SearchHeader({required this.shell, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(children: [
        // Search bar
        TextField(
          onChanged: (v) => shell.setState(() => shell.searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Ҷустуҷӯ дар ҳамаи эълонҳо...',
            prefixIcon: Icon(Icons.search, color: p.muted),
            suffixIcon: shell.searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.muted),
                    onPressed: () => shell.setState(() => shell.searchQuery = ''))
                : null,
          ),
        ),
        const SizedBox(height: 8),
        // City selector — динамикӣ аз Schema
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            initialValue: shell.city,
            onSelected: (v) => shell.setState(() { shell.city = v; shell.selectedDistricts.clear(); }),
            itemBuilder: (_) => [for (final c in shell.schema.cityNames) PopupMenuItem(value: c, child: Text(c))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surface, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.hairline),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_outlined, size: 18, color: p.brand),
                const SizedBox(width: 6),
                Text(shell.city, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: p.text)),
                Icon(Icons.arrow_drop_down, color: p.textMid),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _QuickFilterRibbon extends StatelessWidget {
  final RootShellState shell;
  final Palette p;
  const _QuickFilterRibbon({required this.shell, required this.p});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, {IconData? icon, VoidCallback? onTap, bool active = false}) {
      return ActionChip(
        backgroundColor: active ? p.brand.withOpacity(0.1) : p.surface,
        side: BorderSide(color: active ? p.brand : p.hairline),
        avatar: icon != null ? Icon(icon, size: 16, color: active ? p.brand : p.textMid) : null,
        label: Text(label, style: TextStyle(fontSize: 13, color: active ? p.brand : p.text)),
        onPressed: onTap,
      );
    }
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          chip('Филтрҳо', icon: Icons.tune, onTap: () => _openFilters(context)),
          chip('Бандҳо', icon: Icons.arrow_drop_down,
              onTap: () => shell.setState(() { shell.tab = 1; })),
          chip('Нарх', icon: Icons.payments_outlined, onTap: () => _openFilters(context)),
          chip('Маҳалла', icon: Icons.place_outlined, onTap: () => _openFilters(context)),
          chip('Танҳо аксдор', active: shell.onlyPhotos,
              onTap: () => shell.setState(() => shell.onlyPhotos = !shell.onlyPhotos)),
          chip('Бо мубодила', active: shell.onlyExchange,
              onTap: () => shell.setState(() => shell.onlyExchange = !shell.onlyExchange)),
          if (shell.activeCat != null)
            ActionChip(
              backgroundColor: p.brand.withOpacity(0.1),
              side: BorderSide(color: p.brand),
              avatar: Icon(Icons.close, size: 14, color: p.brand),
              label: Text(shell.activeCat!, style: TextStyle(fontSize: 13, color: p.brand)),
              onPressed: () => shell.setState(() => shell.activeCat = null),
            ),
        ],
      ),
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => FilterSheet(shell: shell),
    );
  }
}

class FilterSheet extends StatefulWidget {
  final RootShellState shell;
  const FilterSheet({super.key, required this.shell});
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Palette p = Palette(widget.shell.widget.isDark);
  late bool onlyFree = widget.shell.onlyFree;
  late bool onlyPhotos = widget.shell.onlyPhotos;
  late bool onlyExchange = widget.shell.onlyExchange;
  late bool onlyUrgent = widget.shell.onlyUrgent;
  late Set<String> districts = {...widget.shell.selectedDistricts};
  final minC = TextEditingController(), maxC = TextEditingController();

  List<String> get _districtOptions => widget.shell.schema.districtsFor(widget.shell.city);

  @override
  Widget build(BuildContext context) {
    // Майдонҳои динамикӣ аз Schema (глобалӣ + мутобиқи банди фаъол)
    final cat = widget.shell.activeCat;
    final dynamicGroups = widget.shell.schema.fields
        .where((f) => f.categoryPath == null ||
            (cat != null && cat.startsWith(f.categoryPath!.split('/').first)))
        .toList();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Филтрҳо', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 12),
          Text('Маҳалла — ${widget.shell.city}', style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (final d in _districtOptions)
                FilterChip(
                  selected: districts.contains(d),
                  label: Text(d, style: const TextStyle(fontSize: 12)),
                  selectedColor: p.brand.withOpacity(0.12),
                  checkmarkColor: p.brand,
                  onSelected: (v) => setState(() => v ? districts.add(d) : districts.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Нарх (с.)', style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
          Row(children: [
            Expanded(child: TextField(controller: minC, keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Аз'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: maxC, keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'То'))),
          ]),
          const SizedBox(height: 8),
          _switch('Танҳо ройгон', onlyFree, (v) => setState(() => onlyFree = v)),
          _switch('Танҳо аксдор', onlyPhotos, (v) => setState(() => onlyPhotos = v)),
          _switch('Бо мубодила', onlyExchange, (v) => setState(() => onlyExchange = v)),
          _switch('Фаврӣ', onlyUrgent, (v) => setState(() => onlyUrgent = v)),
          // ===== МАЙДОНҲОИ ДИНАМИКӢ (аз Schema — админ ҳар вақт илова мекунад) =====
          for (final g in dynamicGroups) ...[
            const SizedBox(height: 12),
            Text(g.title, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                for (final v in g.values)
                  FilterChip(
                    selected: _dynSel[g.key] == v,
                    label: Text(v, style: const TextStyle(fontSize: 12)),
                    selectedColor: p.brand.withOpacity(0.12),
                    checkmarkColor: p.brand,
                    onSelected: (_) => setState(() =>
                        _dynSel[g.key] = _dynSel[g.key] == v ? null : v),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.shell.setState(() {
                    widget.shell.selectedDistricts.clear();
                    widget.shell.minPrice = widget.shell.maxPrice = null;
                    widget.shell.onlyFree = widget.shell.onlyPhotos =
                        widget.shell.onlyExchange = widget.shell.onlyUrgent = false;
                    widget.shell.activeCat = null;
                    widget.shell.dynFilterValues.clear();
                    _dynSel.clear();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Тоза кардани филтрҳо'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: p.brand),
                onPressed: () {
                  widget.shell.setState(() {
                    widget.shell.selectedDistricts
                      ..clear()
                      ..addAll(districts);
                    widget.shell.minPrice = int.tryParse(minC.text);
                    widget.shell.maxPrice = int.tryParse(maxC.text);
                    widget.shell.onlyFree = onlyFree;
                    widget.shell.onlyPhotos = onlyPhotos;
                    widget.shell.onlyExchange = onlyExchange;
                    widget.shell.onlyUrgent = onlyUrgent;
                    for (final e in _dynSel.entries) {
                      if (e.value != null) widget.shell.dynFilterValues[e.key] = e.value!;
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text('Нишон додан'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  final Map<String, String?> _dynSel = {};

  Widget _switch(String label, bool v, ValueChanged<bool> on) => SwitchListTile(
        title: Text(label, style: TextStyle(fontSize: 14, color: p.text)),
        value: v, onChanged: on,
        contentPadding: EdgeInsets.zero,
        activeColor: p.brand,
        dense: true,
      );
}

class AdCard extends StatelessWidget {
  final Ad ad;
  final RootShellState shell;
  final Palette p;
  const AdCard({super.key, required this.ad, required this.shell, required this.p});

  @override
  Widget build(BuildContext context) {
    final marked = shell.bookmarks.contains(ad.id);
    return Material(
      color: p.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: p.hairline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => shell.openAd(ad),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT: title/specs/price/meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text, height: 1.25)),
                    const SizedBox(height: 3),
                    Text(ad.specs, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.textMid)),
                    const Spacer(),
                    Text(priceLabel(ad),
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600,
                            color: ad.price == null ? C.success : p.text)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Flexible(child: Text('${ad.timeAgo} дар ${ad.district}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: p.muted))),
                      if (ad.exchange) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: p.brand.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('Мубодила', style: TextStyle(fontSize: 10.5, color: p.brand)),
                        ),
                      ],
                      if (ad.urgent) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('Фаврӣ', style: const TextStyle(fontSize: 10.5, color: Colors.deepOrange)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // RIGHT: art thumbnail + heart
              SizedBox(
                width: 104, height: 104,
                child: Stack(children: [
                  Positioned.fill(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AdArt(ad),
                  )),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => shell.setState(() =>
                          marked ? shell.bookmarks.remove(ad.id) : shell.bookmarks.add(ad.id)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(marked ? Icons.favorite : Icons.favorite_border,
                            size: 16, color: marked ? p.brand : C.textMid),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ TAB 2: БАНДҲО (Drill-down — динамикӣ аз Schema) ============================
class CategoriesTab extends StatefulWidget {
  final RootShellState shell;
  const CategoriesTab({super.key, required this.shell});
  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final List<SchemaNode> path = [];

  int countFor(String name) => widget.shell.ads.where((a) => a.catPath.contains(name)).length;

  List<SchemaNode> _nodesAt() {
    var nodes = widget.shell.schema.visibleCategories;
    for (final node in path) {
      nodes = node.children.where((n) => !n.hidden).toList();
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette(widget.shell.widget.isDark);
    final nodes = _nodesAt();
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (path.isNotEmpty)
              IconButton(
                onPressed: () => setState(() => path.removeLast()),
                icon: Icon(Icons.arrow_back, color: p.text),
              ),
            Expanded(
              child: Text(path.isEmpty ? 'Бандҳо' : path.last.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
            ),
            if (path.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => path.clear()),
                child: Text('Ҳамаи бандҳо', style: TextStyle(color: p.brand, fontSize: 13)),
              ),
          ]),
        ),
        Divider(height: 1, color: p.hairline),
        Expanded(
          child: ListView.builder(
            itemCount: nodes.length,
            itemBuilder: (_, i) {
              final n = nodes[i];
              final active = n.name == widget.shell.activeCat?.split('/').last;
              return Column(children: [
                ListTile(
                  leading: n.icon != '•'
                      ? Text(n.icon, style: const TextStyle(fontSize: 20))
                      : null,
                  title: Text(n.name, style: TextStyle(
                      fontSize: 15, fontWeight: path.isEmpty ? FontWeight.w600 : FontWeight.w400,
                      color: active ? p.brand : p.text)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${countFor(n.name)}', style: TextStyle(fontSize: 13, color: p.muted)),
                    if (n.children.isNotEmpty)
                      Icon(Icons.chevron_right, size: 20, color: p.muted)
                    else
                      Icon(Icons.arrow_forward_ios, size: 14, color: p.muted),
                  ]),
                  onTap: () {
                    if (n.children.isNotEmpty) {
                      setState(() => path.add(n));
                    } else {
                      // Leaf — филтри feed аз рӯйхати волидайн
                      final root = path.isNotEmpty ? path.first.name : n.name;
                      widget.shell.setState(() => widget.shell.activeCat = root);
                      setState(() => path.clear());
                      widget.shell.setState(() => widget.shell.tab = 0);
                    }
                  },
                ),
                Divider(height: 1, color: p.hairline),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

// ============================ TAB 3: САБТИ ЭЪЛОН (Wizard — динамикӣ) ============================
class PostWizardTab extends StatefulWidget {
  final RootShellState shell;
  const PostWizardTab({super.key, required this.shell});
  @override
  State<PostWizardTab> createState() => _PostWizardTabState();
}

class _PostWizardTabState extends State<PostWizardTab> {
  int step = 0;
  String? category, subcategory;
  final titleC = TextEditingController(), descC = TextEditingController(),
      priceC = TextEditingController(), phoneC = TextEditingController();
  bool free = false, negotiable = false, exchange = false;
  String? city, district;
  String? condition, schedule, season, experience;
  final Map<String, String> customValues = {};
  String chosenIcon = '📦';
  final iconChoices = ['📦', '🏠', '🚗', '📱', '💻', '🧸', '🐾', '👕', '🛋️', '🎸'];

  late Palette p;

  @override
  void initState() {
    super.initState();
    city = widget.shell.city;
  }

  List<String> get _districtOptions => widget.shell.schema.districtsFor(city ?? 'Душанбе');

  @override
  Widget build(BuildContext context) {
    p = Palette(widget.shell.widget.isDark);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Сабти эълони ройгон',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
          Text('Қадами ${step + 1} аз 3', style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (step + 1) / 3,
            backgroundColor: p.surface, color: p.brand, minHeight: 4,
          ),
          const SizedBox(height: 12),
          Expanded(child: IndexedStack(index: step, children: [
            _stepCategory(), _stepDetails(), _stepContact(),
          ])),
          Row(children: [
            if (step > 0)
              Expanded(child: OutlinedButton(
                onPressed: () => setState(() => step--),
                child: const Text('Бозгашт'))),
            if (step > 0) const SizedBox(width: 8),
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.brand),
              onPressed: _next,
              child: Text(step == 2 ? 'Нашр кардан — Ройгон' : 'Идома'))),
          ]),
        ]),
      ),
    );
  }

  void _next() {
    if (step == 0 && category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аввал бандро интихоб кунед.')));
      return;
    }
    if (step == 2) {
      _publish();
    } else {
      setState(() => step++);
    }
  }

  void _publish() {
    // Сессия админ ҳамагон пӯшида бошад ҳам, эълони оддӣ ройгон аст.
    final chosenCity = city ?? widget.shell.city;
    final chosenDistrict = district ?? (_districtOptions.isNotEmpty ? _districtOptions.first : 'Марказ');
    final extra = <String, String>{
      if (schedule != null) 'Реҷаи кор': schedule!,
      if (season != null) 'Фасли корӣ': season!,
      if (experience != null) 'Таҷриба': experience!,
      ...customValues,
    };
    final ad = Ad(
      id: 'my${DateTime.now().millisecondsSinceEpoch}',
      title: titleC.text.trim().isEmpty ? 'Эълони нав' : titleC.text.trim(),
      catPath: '$category / $subcategory',
      district: chosenDistrict, city: chosenCity, specs: condition ?? 'Дар ҳолати хуб',
      timeAgo: 'Ҳоло', condition: condition ?? 'Дар ҳолати хуб',
      price: free ? null : int.tryParse(priceC.text),
      icon: Icons.inventory_2, artColors: const [Color(0xFFA62626), Color(0xFFD94141)],
      specsTable: {
        'Ҳолат': condition ?? 'Дар ҳолати хуб',
        'Шаҳр': chosenCity,
        'Ноҳия': chosenDistrict,
        ...extra,
      },
      description: descC.text.trim(),
      phone: phoneC.text.trim().isEmpty ? '+992 00 000 00 00' : phoneC.text.trim(),
      seller: 'Девори ман',
      negotiable: negotiable, exchange: exchange, photos: 1,
    );
    widget.shell.setState(() {
      widget.shell.ads.insert(0, ad);
      widget.shell.myAds.add(ad);
      widget.shell.tab = 0;
    });
    setState(() => step = 0);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эълон нашр шуд — 100% Ройгон! ✅')));
  }

  Widget _stepCategory() {
    final cats = widget.shell.schema.visibleCategories;
    return ListView.builder(
      itemCount: cats.length,
      itemBuilder: (_, i) => ListTile(
        leading: Text(cats[i].icon, style: const TextStyle(fontSize: 20)),
        title: Text(cats[i].name, style: TextStyle(color: p.text, fontSize: 15)),
        subtitle: subcategory != null && cats[i].name == category
            ? Text('Интихобшуда: $subcategory', style: TextStyle(color: p.brand, fontSize: 12))
            : null,
        trailing: Icon(Icons.chevron_right, color: p.muted),
        onTap: () => _pickSub(cats[i]),
      ),
    );
  }

  void _pickSub(SchemaNode cat) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16),
              child: Text('${cat.icon} ${cat.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
          for (final s in cat.children.where((n) => !n.hidden))
            ListTile(
              title: Text(s.name, style: TextStyle(fontSize: 14, color: p.text)),
              onTap: () {
                setState(() { category = cat.name; subcategory = s.name; step = 1; });
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }

  Widget _stepDetails() {
    final cond = widget.shell.schema.field('condition');
    final sched = widget.shell.schema.field('schedule');
    final seasonF = widget.shell.schema.field('season');
    final expF = widget.shell.schema.field('experience');
    final customs = widget.shell.schema.customFields;
    return ListView(children: [
      // Photo preview (gradient art placeholders — offline!)
      Text('Аксҳо (ройгон)', style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
      const SizedBox(height: 6),
      SizedBox(
        height: 90,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final ic in iconChoices.take(4))
              GestureDetector(
                onTap: () => setState(() => chosenIcon = ic),
                child: Container(
                  width: 90, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: chosenIcon == ic ? p.brand : p.hairline, width: 2),
                    gradient: LinearGradient(colors: [
                      chosenIcon == ic ? C.brand.withOpacity(0.15) : p.surface,
                      chosenIcon == ic ? C.brandDark.withOpacity(0.15) : p.surface,
                    ]),
                  ),
                  child: Center(child: Text(ic, style: TextStyle(
                      fontSize: 30, color: chosenIcon == ic ? p.brand : p.muted))),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextField(controller: titleC, maxLength: 70,
          decoration: const InputDecoration(hintText: 'Номи эълон (масалан: iPhone 13 128GB)')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _toggle('Ройгон', free, (v) => setState(() { free = v; if (v) priceC.clear(); }))),
        const SizedBox(width: 8),
        Expanded(child: _toggle('Шартномавӣ', negotiable, (v) => setState(() => negotiable = v))),
        const SizedBox(width: 8),
        Expanded(child: _toggle('Мубодила', exchange, (v) => setState(() => exchange = v))),
      ]),
      const SizedBox(height: 8),
      if (!free)
        TextField(controller: priceC, keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Нарх (с.)')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: city, dropdownColor: p.surface,
          items: [for (final c in widget.shell.schema.cityNames) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() { city = v; district = null; }),
          decoration: const InputDecoration(hintText: 'Шаҳр'))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          value: district, dropdownColor: p.surface,
          items: [for (final d in _districtOptions) DropdownMenuItem(value: d, child: Text(d))],
          onChanged: (v) => setState(() => district = v),
          decoration: const InputDecoration(hintText: 'Ноҳия'))),
      ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: condition, dropdownColor: p.surface,
        items: [for (final v in (cond?.values ?? ['Нав', 'Дар ҳолати хуб', 'Истифодашуда']))
          DropdownMenuItem(value: v, child: Text(v))],
        onChanged: (v) => setState(() => condition = v),
        decoration: InputDecoration(hintText: cond?.title ?? 'Ҳолат'),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: schedule, dropdownColor: p.surface, isExpanded: true,
          items: [for (final v in (sched?.values ?? ['Рӯзона'])) DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => schedule = v),
          decoration: InputDecoration(hintText: sched?.title ?? 'Реҷаи кор', contentPadding: const EdgeInsets.symmetric(horizontal: 10)))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(
          value: season, dropdownColor: p.surface, isExpanded: true,
          items: [for (final v in (seasonF?.values ?? ['Солона'])) DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => season = v),
          decoration: InputDecoration(hintText: seasonF?.title ?? 'Фасли корӣ', contentPadding: const EdgeInsets.symmetric(horizontal: 10)))),
      ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: experience, dropdownColor: p.surface,
        items: [for (final v in (expF?.values ?? ['Дилхоҳ'])) DropdownMenuItem(value: v, child: Text(v))],
        onChanged: (v) => setState(() => experience = v),
        decoration: InputDecoration(hintText: expF?.title ?? 'Таҷриба'),
      ),
      // ===== Майдонҳои динамикӣ-и custom (аз Schema) =====
      for (final cf in customs) ...[
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(hintText: '${cf.title} (динамикӣ)'),
          onChanged: (v) => customValues[cf.title] = v,
        ),
      ],
      const SizedBox(height: 8),
      TextField(controller: descC, maxLines: 4, maxLength: 500,
          decoration: const InputDecoration(hintText: 'Тавсифи муфассал...')),
    ]);
  }

  Widget _stepContact() => ListView(children: [
    // OTP маскалкунии PII — DATA.md
    Text('Телефон тамос (PII — маскал мешавад)',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: p.textMid)),
    const SizedBox(height: 6),
    TextField(
      controller: phoneC,
      keyboardType: TextInputType.phone,
      autofillHints: null, // autocomplete/clipboard cache excludes (DATA.md)
      decoration: const InputDecoration(hintText: '+992 XX XXX XX XX'),
    ),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.brand.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.brand.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.security_outlined, size: 18, color: p.brand),
          const SizedBox(width: 6),
          Text('Ҳушдорҳои амниятӣ', style: TextStyle(fontWeight: FontWeight.w700, color: p.brand)),
        ]),
        const SizedBox(height: 6),
        Text('• Рақами телефон дар экран ҳамчун ${SecurityAuthService.maskPhone(phoneC.text.isEmpty ? '+992000000000' : phoneC.text)} нишон дода мешавад.\n• Телефон/Email дар логҳо маскал мешаванд.\n• OTP баъди тасдиқ 3 дақиқа пурра нест мешавад.',
            style: TextStyle(fontSize: 12.5, color: p.textMid, height: 1.5)),
      ]),
    ),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('✅ Нашри эълон 100% РОЙГОН аст — бе VIP, бе ТОР, бе пардохт.',
          style: TextStyle(color: C.success, fontWeight: FontWeight.w600, fontSize: 13)),
    ),
  ]);

  Widget _toggle(String label, bool v, ValueChanged<bool> on) => GestureDetector(
    onTap: () => on(!v),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: v ? p.brand.withOpacity(0.12) : p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: v ? p.brand : p.hairline),
      ),
      child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: v ? FontWeight.w700 : FontWeight.w400,
          color: v ? p.brand : p.text))),
    ),
  );
}

// ============================ TAB 4: ЧАТ ============================
const quickReplies = ['Салом, ҳоло ҳам ҳаст?', 'Нархи охираш чанд?', 'Дар куҷо дидан мумкин?'];

class ChatTab extends StatelessWidget {
  final RootShellState shell;
  const ChatTab({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final p = Palette(shell.widget.isDark);
    if (shell.conversations.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: p.muted),
        const SizedBox(height: 12),
        Text('Ҳанӯз гуфтугӯй нест', style: TextStyle(color: p.textMid, fontSize: 15)),
        Text('Дар саҳифаи эълон тугмаи «Чат»-ро пахш кунед',
            style: TextStyle(color: p.muted, fontSize: 13)),
      ]));
    }
    return SafeArea(
      child: ListView.builder(
        itemCount: shell.conversations.length,
        itemBuilder: (_, i) {
          final c = shell.conversations[i];
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: AdArt(c.ad)),
            title: Text(c.seller, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            subtitle: Text(c.msgs.isEmpty ? '' : c.msgs.last.text,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.textMid, fontSize: 13)),
            trailing: c.unread > 0
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                    child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 12)))
                : Text('${c.msgs.length}', style: TextStyle(color: p.muted, fontSize: 12)),
            onTap: () => _openConversation(context, c),
          );
        },
      ),
    );
  }

  void _openConversation(BuildContext context, Conversation c) {
    shell.setState(() => c.unread = 0);
    shell._recalcUnread();
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => _ChatScreen(conversation: c, shell: shell)));
  }
}

class _ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final RootShellState shell;
  const _ChatScreen({required this.conversation, required this.shell});
  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final msgC = TextEditingController();
  final _controller = ScrollController();

  void send(String text) {
    if (text.trim().isEmpty) return;
    setState(() => widget.conversation.msgs.add(ChatMsg(text.trim(), me: true)));
    msgC.clear();
    widget.shell.simulateSellerReply(widget.conversation);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_controller.hasClients) {
        _controller.animateTo(_controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette(widget.shell.widget.isDark);
    final ad = widget.conversation.ad;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.conversation.seller, style: const TextStyle(fontSize: 15)),
          Text('${priceLabel(ad)} • ${ad.district}',
              style: TextStyle(fontSize: 12, color: p.textMid)),
        ]),
      ),
      body: Column(children: [
        // Pinned ad header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: p.hairline), borderRadius: BorderRadius.circular(8),
            color: p.surface,
          ),
          child: Row(children: [
            SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: AdArt(ad))),
            const SizedBox(width: 10),
            Expanded(child: Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.text))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.all(12),
            itemCount: widget.conversation.msgs.length,
            itemBuilder: (_, i) {
              final m = widget.conversation.msgs[i];
              return Align(
                alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: m.me ? p.brand : p.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(m.text, style: TextStyle(
                      color: m.me ? Colors.white : p.text, fontSize: 14)),
                ),
              );
            },
          ),
        ),
        // Quick replies
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [for (final q in quickReplies)
              Padding(padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(q, style: TextStyle(fontSize: 12.5, color: p.brand)),
                  backgroundColor: p.brand.withOpacity(0.07),
                  side: BorderSide(color: p.brand.withOpacity(0.3)),
                  onPressed: () => send(q)))),
          ],
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: msgC,
                onSubmitted: send,
                decoration: const InputDecoration(hintText: 'Паём нависед...'))),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: p.brand,
                child: IconButton(
                  icon: const Icon(Icons.send, size: 18, color: Colors.white),
                  onPressed: () => send(msgC.text)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ============================ TAB 5: ДЕВОРИ МАН (Auth + Profile) ============================
class MyDevorTab extends StatelessWidget {
  final RootShellState shell;
  final VoidCallback onToggleTheme;
  const MyDevorTab({super.key, required this.shell, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityAuthService.instance,
      builder: (context, _) {
        final auth = SecurityAuthService.instance;
        final p = Palette(shell.widget.isDark);
        if (!auth.isLoggedIn) return _AuthScreen(shell: shell, p: p);
        return _ProfileScreen(shell: shell, p: p, onToggleTheme: onToggleTheme);
      },
    );
  }
}

class _AuthScreen extends StatefulWidget {
  final RootShellState shell;
  final Palette p;
  const _AuthScreen({required this.shell, required this.p});
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  bool isRegister = false;
  final emailC = TextEditingController(), passC = TextEditingController(), otpC = TextEditingController();
  bool obscure = true;
  String? otpIssuedFor;

  @override
  Widget build(BuildContext context) {
    final auth = SecurityAuthService.instance;
    final lock = auth.remainingLock();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 24),
          Icon(Icons.shield_outlined, size: 64, color: widget.p.brand),
          const SizedBox(height: 8),
          Text('Девори ман', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: widget.p.text)),
          Text(isRegister ? 'Қайд кардани ҳисоби нав' : 'Воридшавӣ',
              textAlign: TextAlign.center, style: TextStyle(color: widget.p.textMid, fontSize: 14)),
          const SizedBox(height: 20),

          // — Brute-force lock banner (AUTHENTICATION.md) —
          if (lock != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.p.brand.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.p.brand),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline, color: C.brand),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'ҚУЛФ ШУД: Ҳисоб ба мӯҳлати ${lock.inMinutes}д ${lock.inSeconds % 60}с қулф шуд.',
                  style: TextStyle(color: widget.p.text, fontSize: 13))),
              ]),
            ),

          TextField(
            controller: emailC,
            autofillHints: null,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email (masalan: ba@gmail.com)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passC,
            obscureText: obscure,
            autofillHints: null,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Парол (≥8 аломат)',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.p.brand, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: lock != null ? null : () => _submit(),
            child: Text(isRegister ? 'Қайд кардан' : 'Ворид шавед',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => setState(() => isRegister = !isRegister),
            child: Text(isRegister ? 'Ҳисоб дорам — Ворид шавед' : 'Ҳисоб надорам — Қайд кардан',
                style: TextStyle(color: widget.p.brand, fontSize: 13)),
          ),

          // — OTP demo (DATA.md: ephemeral) —
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final e = emailC.text.trim();
              if (e.isEmpty) return;
              setState(() => otpIssuedFor = SecurityAuthService.instance.issueOtp(e));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Рамзи OTP сохта шуд (TTL 3 дақиқа — баъди истифода ПОК мешавад)')));
            },
            child: const Text('Демо: гирифтани рамзи OTP'),
          ),
          if (otpIssuedFor != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: otpC,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofillHints: null,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'Рамзи OTP (6 рақам)'),
            ),
            const SizedBox(height: 6),
            Text('OTP дар логҳо: ${'*' * otpIssuedFor!.length} (ниҳон) — маскал DATA.md',
                style: TextStyle(fontSize: 11.5, color: widget.p.muted)),
            TextButton(
              onPressed: () {
                final ok = SecurityAuthService.instance.verifyOtp(otpC.text);
                setState(() { otpC.clear(); });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'OTP тасдиқ ва ПОК КАРДА ШУД ✅' : 'Рамзи OTP нодуруст — нест шуд ❌')));
              },
              child: const Text('Тасдиқи OTP'),
            ),
          ],

          // — Аудит —
          const SizedBox(height: 16),
          Text('Ҳушдорҳои амниятӣ / Аудит (аслӣ)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: widget.p.text)),
          const SizedBox(height: 6),
          ...SecurityAuthService.instance.auditLog.take(6).map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(_iconFor(e.type), size: 15,
                  color: e.type == AuthEventType.loginFailed || e.type == AuthEventType.loginLocked
                      ? widget.p.brand : C.success),
              const SizedBox(width: 8),
              Expanded(child: Text('${e.label} — ${e.detail}',
                  style: TextStyle(fontSize: 12, color: widget.p.textMid))),
            ]),
          )),
        ]),
      ),
    );
  }

  IconData _iconFor(AuthEventType t) =>
      (t == AuthEventType.loginFailed || t == AuthEventType.loginLocked)
          ? Icons.warning_amber_outlined : Icons.check_circle_outline;

  Future<void> _submit() async {
    final auth = SecurityAuthService.instance;
    final res = isRegister
        ? await auth.register(emailC.text, passC.text)
        : await auth.login(emailC.text, passC.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    if (res.status == AuthStatus.wrongCredentials) passC.clear(); // RAM wipe
  }
}

class _ProfileScreen extends StatelessWidget {
  final RootShellState shell;
  final Palette p;
  final VoidCallback onToggleTheme;
  const _ProfileScreen({required this.shell, required this.p, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final auth = SecurityAuthService.instance;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Header
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: p.brand,
            child: Text(auth.session!.email[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(SecurityAuthService.maskEmail(auth.session!.email), // PII masking (DATA.md)
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text('Сессия фаъол • ${auth.deviceFingerprint}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.muted))),
            ]),
          ])),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('Эълонҳои ман', p),
        if (shell.myAds.items.isEmpty)
          Text('Ҳанӯз эълон нашр накардаед', style: TextStyle(color: p.muted, fontSize: 13)),
        ...shell.myAds.items.map((a) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: AdArt(a))),
          title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: p.text)),
          subtitle: Text(priceLabel(a), style: TextStyle(fontSize: 12.5, color: C.success)),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: p.brand),
            onPressed: () {
              shell.setState(() { shell.ads.removeWhere((x) => x.id == a.id); });
              shell.myAds.remove(a.id);
            },
          ),
        )),
        const Divider(),
        _sectionTitle('Нишоншудаҳо (Bookmarks)', p),
        if (shell.bookmarks.isEmpty)
          Text('Ҳанӯз чиз нишон нашудааст', style: TextStyle(color: p.muted, fontSize: 13)),
        ...shell.ads.where((a) => shell.bookmarks.contains(a.id)).map((a) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: AdArt(a))),
          title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: p.text)),
          subtitle: Text(priceLabel(a), style: TextStyle(fontSize: 12.5, color: p.textMid)),
          onTap: () => shell.openAd(a),
        )),
        const Divider(),
        _sectionTitle('Дидашудаҳои охир', p),
        ...shell.recentlyViewed.take(5).map((id) {
          final a = shell.ads.where((x) => x.id == id).toList();
          if (a.isEmpty) return const SizedBox.shrink();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.history, color: p.muted),
            title: Text(a.first.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: p.text)),
            onTap: () => shell.openAd(a.first),
          );
        }),
        const Divider(),
        _sectionTitle('Танзимот ва амният', p),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Ҳолати шабона (Dark Mode)', style: TextStyle(fontSize: 14, color: p.text)),
          value: shell.widget.isDark, onChanged: (_) => onToggleTheme(),
          activeColor: p.brand,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.security_outlined, color: p.brand),
          title: Text('Ҳушдорҳои амниятӣ — аудит', style: TextStyle(fontSize: 14, color: p.text)),
          subtitle: Text('${auth.auditLog.length} ҳодиса сабт шудааст',
              style: TextStyle(fontSize: 12, color: p.muted)),
          onTap: () => _showAudit(context, auth, p),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: p.brand.withOpacity(0.1),
            foregroundColor: p.brand,
            padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () async {
            // STRICT SESSION TERMINATION (AUTHENTICATION.md)
            final nav = Navigator.of(context, rootNavigator: true);
            final messenger = ScaffoldMessenger.of(context);
            await SecurityAuthService.instance.logout();
            nav.popUntil((r) => r.isFirst);
            messenger.showSnackBar(const SnackBar(
                content: Text('Баромадан: токенҳо revoke, storage пок, RAM wipe ✅')));
          },
          child: const Text('Баромадан (Logout)', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),
        Center(child: Text('Созанда: Хайдарзода (Haydarzoda) • 100% Ройгон',
            style: TextStyle(color: p.muted, fontSize: 12))),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _sectionTitle(String t, Palette p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
  );

  void _showAudit(BuildContext context, SecurityAuthService auth, Palette p) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: p.surface,
      title: Text('Аудити амният', style: TextStyle(color: p.text)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: auth.auditLog.length,
          itemBuilder: (_, i) {
            final e = auth.auditLog[i];
            return ListTile(
              dense: true,
              leading: Icon(e.type == AuthEventType.loginFailed || e.type == AuthEventType.loginLocked
                  ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                  size: 16, color: e.type == AuthEventType.loginFailed ? p.brand : C.success),
              title: Text(e.label, style: TextStyle(fontSize: 13, color: p.text)),
              subtitle: Text('${e.at.hour}:${e.at.minute.toString().padLeft(2, '0')} • ${e.deviceFingerprint} • ${e.ipRegion}',
                  style: TextStyle(fontSize: 11, color: p.muted)),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Пӯшидан'))],
    ));
  }
}

// ============================ AD DETAIL SCREEN ============================
class AdDetailScreen extends StatelessWidget {
  final Ad ad;
  final VoidCallback onClose;
  final RootShellState shell;
  const AdDetailScreen({super.key, required this.ad, required this.onClose, required this.shell});

  @override
  Widget build(BuildContext context) {
    final p = Palette(shell.widget.isDark);
    final phoneMasked = SecurityAuthService.maskPhone(ad.phone);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onClose),
        title: Text(ad.catPath, style: TextStyle(fontSize: 12.5, color: p.textMid)),
        actions: [
          IconButton(
            icon: Icon(shell.bookmarks.contains(ad.id) ? Icons.favorite : Icons.favorite_border,
                color: shell.bookmarks.contains(ad.id) ? p.brand : p.textMid),
            onPressed: () => shell.setState(() =>
                shell.bookmarks.contains(ad.id) ? shell.bookmarks.remove(ad.id) : shell.bookmarks.add(ad.id)),
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: p.textMid),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'devor.tj/ad/${ad.id}'));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ҳавола нусха шуд 🔗')));
            },
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: AdArt(ad, big: true)),
          const SizedBox(height: 16),
          Text(ad.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 6),
          Text('${ad.timeAgo} • ${ad.city}, ${ad.district}',
              style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 16),
          // Specs 2-col table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: p.hairline), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              for (final e in ad.specsTable.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.hairline))),
                  child: Row(children: [
                    Expanded(child: Text(e.key, style: TextStyle(fontSize: 13.5, color: p.textMid))),
                    Expanded(child: Text(e.value, textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.text))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Тавсиф', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 6),
          Text(ad.description, style: TextStyle(fontSize: 14, color: p.text, height: 1.6)),
          const SizedBox(height: 20),
          // Divar Safety Warning
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.brand.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.brand.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.shield_outlined, size: 20, color: p.brand),
                const SizedBox(width: 8),
                Text('Ҳушдорҳои пеш аз харид',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.brand)),
              ]),
              const SizedBox(height: 8),
              Text(
                '• Ҳеҷ гоҳ пешакӣ пул насозед — танҳо ҳангоми дидани мол пардохт кунед.\n'
                '• Молро пеш аз харид дар ҷой санҷед (IMEI, ҳолат, ҳуҷҷатҳо).\n'
                '• Бо ҳамаи дидан дар ҷойи ҷамъиятӣ вохӯрӣ кунед.\n'
                '• Агар эълон гумонбар бошад — «Гузориш»-ро пахш кунед.',
                style: TextStyle(fontSize: 13, color: p.text, height: 1.6),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ])),
        // Pinned bottom bar
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: BorderSide(color: p.hairline)),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(Icons.chat_bubble_outline, size: 18, color: p.brand),
                label: const Text('Чат'),
                onPressed: () { onClose(); shell.startChatWith(ad); },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: p.brand),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text('Тамос: $phoneMasked', style: const TextStyle(fontSize: 12.5)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ad.phone));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Рақам нусха шуд: $phoneMasked')));
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ============================ MAP SCREEN ============================
class MapScreen extends StatelessWidget {
  final RootShellState shell;
  const MapScreen({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final p = Palette(shell.widget.isDark);
    final shown = shell.filtered.take(8).toList();
    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(title: const Text('Харитаи эълонҳо'), backgroundColor: p.bg),
      body: Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: _CityMapPainter(p: p),
        ),
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: 30 + (i % 3) * 110.0,
            top: 80 + (i ~/ 3) * 140.0,
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => _MapPreviewCard(ad: shown[i], shell: shell),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
                ),
                child: Text(priceLabel(shown[i]),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.brand)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  final Ad ad;
  final RootShellState shell;
  const _MapPreviewCard({required this.ad, required this.shell});
  @override
  Widget build(BuildContext context) {
    final p = Palette(shell.widget.isDark);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          SizedBox(width: 80, height: 80, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: AdArt(ad))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            const SizedBox(height: 4),
            Text(priceLabel(ad), style: TextStyle(fontWeight: FontWeight.w700, color: p.brand)),
          ])),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.brand),
            onPressed: () { Navigator.pop(context); shell.openAd(ad); },
            child: const Text('Кушодани эълон'),
          ),
        ),
      ]),
    );
  }
}

class _CityMapPainter extends CustomPainter {
  final Palette p;
  _CityMapPainter({required this.p});
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = p.surface;
    canvas.drawRect(Offset.zero & size, bg);
    final road = Paint()
      ..color = p.hairline
      ..strokeWidth = 3;
    for (var x = 0.0; x < size.width; x += 90) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    for (var y = 0.0; y < size.height; y += 110) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
    // Рӯди Варзоб — хатти кобудӣ
    final river = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.35)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.7, 0)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.4, size.width * 0.65, size.height);
    canvas.drawPath(path, river);
  }
  @override
  bool shouldRepaint(covariant _CityMapPainter o) => o.p.dark != p.dark;
}

// ============================================================================
//  SUPER-ADMIN GATE — ZERO-EXPOSURE OWNER-DEFINED CREDENTIALS
// ============================================================================
class AdminGateDialog extends StatefulWidget {
  final RootShellState shell;
  const AdminGateDialog({super.key, required this.shell});
  @override
  State<AdminGateDialog> createState() => _AdminGateDialogState();
}

class _AdminGateDialogState extends State<AdminGateDialog> {
  bool? _exists; // null = дурнамо
  final loginC = TextEditingController();
  final passC = TextEditingController();
  final confirmC = TextEditingController();
  bool obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final e = await SecurityAuthService.instance.adminCredentialsExist();
    if (mounted) setState(() => _exists = e);
  }

  @override
  void dispose() {
    // DATA.md: парол/логин баъди истифода аз хотираи форма пок мешаванд
    loginC.clear(); passC.clear(); confirmC.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityAuthService.instance,
      builder: (context, _) {
        final auth = SecurityAuthService.instance;
        final adminLock = auth.remainingAdminLock();
        return AlertDialog(
          title: Text(
            _exists == null
                ? '...'
                : (_exists!
                    ? 'Вуруди Супер-Админ'
                    : 'Танзими аввалини Супер-Админ'),
          ),
          content: _exists == null
              ? const SizedBox(width: 60, height: 60,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // — Lockout banner (AUTHENTICATION.md) —
                  if (adminLock != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.brand.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.brand),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lock_outline, size: 18, color: C.brand),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'ҚУЛФ ШУД: ${adminLock.inMinutes}д ${adminLock.inSeconds % 60}с',
                          style: const TextStyle(fontSize: 12.5, color: C.brand, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  if (_exists!) ...[
                    // ===== Вуруди Супер-Админ =====
                    TextField(
                      controller: loginC,
                      autofillHints: null,
                      enableSuggestions: false,
                      decoration: const InputDecoration(hintText: 'Логин'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passC,
                      obscureText: obscure,
                      autofillHints: null,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'Парол',
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ] else ...[
                    // ===== Танзими аввалини Owner (бе пешфарз!) =====
                    Text(
                      'Салом, соҳиби барнома!\nМухтасасҳои Супер-Админ ҳанӯз танзим нашудаанд. '
                      'Логин ва Парол-и СИРРИИ худро ворид кунед — онҳо фавран бо SHA-256 + salt '
                      'hash мешаванд ва ҲЕҶ ГОҲ дар барнома намоиш дода НАМЕШАВАНД.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: loginC,
                      autofillHints: null,
                      enableSuggestions: false,
                      decoration: const InputDecoration(hintText: 'Логин (≥4 аломат)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passC,
                      obscureText: obscure,
                      autofillHints: null,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'Парол (≥8 аломат)',
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmC,
                      obscureText: true,
                      autofillHints: null,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'Тасдиқи парол'),
                    ),
                  ],
                ]),
          actions: _exists == null
              ? null
              : [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Бекор'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.brand),
                    onPressed: (_busy || adminLock != null) ? null : _submit,
                    child: Text(_exists! ? 'Ворид шавед' : 'Эҷод кардан'),
                  ),
                ],
        );
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final auth = SecurityAuthService.instance;
    final AuthResult res;
    if (_exists!) {
      res = await auth.adminLogin(loginC.text, passC.text);
    } else {
      res = await auth.adminInitialize(loginC.text, passC.text, confirmC.text);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    // RAM wipe — DATA.md
    passC.clear(); confirmC.clear();

    if (res.status == AuthStatus.success && _exists!) {
      // Контексти navigator-ро ПЕШ аз pop гирифтан лозим аст
      final rootNav = Navigator.of(context, rootNavigator: true);
      final shellCtx = context;
      Navigator.pop(shellCtx); // пӯшидани gate
      rootNav.push(
        MaterialPageRoute(builder: (_) => SuperAdminPanel(shell: widget.shell)),
      );
    } else if (res.status == AuthStatus.success && !_exists!) {
      // Танзим хатм шуд → ба формаи тозаи «Вуруди Супер-Админ» мегузарем
      loginC.clear();
      setState(() => _exists = true);
    }
  }
}

// ============================================================================
//  SUPER-ADMIN PANEL — UNLIMITED LIVE BUILDER & SCHEMA EDITOR
// ============================================================================
class SuperAdminPanel extends StatefulWidget {
  final RootShellState shell;
  const SuperAdminPanel({super.key, required this.shell});
  @override
  State<SuperAdminPanel> createState() => _SuperAdminPanelState();
}

class _SuperAdminPanelState extends State<SuperAdminPanel> {
  int section = 0;
  // drill-down дар менеджери бандҳо (reference-ҳои зинда дар хотира)
  final List<SchemaNode> catPath = [];

  UnlimitedAppSchemaController get schema => widget.shell.schema;

  @override
  void dispose() {
    // Терминатсияи фаврӣ — ҳатто агар тугмаи баромад пахш нашавад (back gesture)
    SecurityAuthService.instance.terminateAdminSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette(widget.shell.widget.isDark);
    return AnimatedBuilder(
      animation: schema,
      builder: (context, _) => WillPopScope(
        // Терминатсияи фаврӣ — ҳатто ҳангоми back-gesture
        onWillPop: () async {
          SecurityAuthService.instance.terminateAdminSession();
          return true;
        },
        child: Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Панели Супер-Админ', style: TextStyle(fontSize: 16, color: p.text)),
              Text('Schema v${schema.schemaVersion} • Бемаҳдуд • Session: FAЪОЛ',
                  style: TextStyle(fontSize: 11, color: C.success)),
            ]),
            actions: [
              IconButton(
                tooltip: 'Баромадан аз панел',
                icon: Icon(Icons.logout, color: p.brand),
                onPressed: () {
                  SecurityAuthService.instance.terminateAdminSession();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: Column(children: [
            // Section switcher
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.hairline)),
                color: p.bg,
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _secChip(0, '📍 Шаҳрҳо'),
                  _secChip(1, '▦ Бандҳо'),
                  _secChip(2, '🕐 Реҷа/Фасл'),
                  _secChip(3, '🎨 Иконка/Ранг'),
                  _secChip(4, '🚀 Нашр'),
                ],
              ),
            ),
            Expanded(child: IndexedStack(index: section, children: [
              _citiesSection(p), _catsSection(p), _fieldsSection(p), _visualSection(p), _publishSection(p),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _secChip(int i, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label, style: TextStyle(
          fontSize: 12.5, fontWeight: section == i ? FontWeight.w700 : FontWeight.w400)),
      selected: section == i,
      selectedColor: C.brand.withOpacity(0.15),
      checkmarkColor: C.brand,
      onSelected: (_) => setState(() => section = i),
    ),
  );

  // ----------------------------------------------------------------
  // SECTION 1: ШАҲРҲО ВА МАҲАЛЛАҲО (бемаҳдуд)
  // ----------------------------------------------------------------
  Widget _citiesSection(Palette p) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Шаҳрҳо (${schema.cities.length})',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text))),
      ]),
      const SizedBox(height: 8),
      _addRow(p, 'Номи шаҳри нав...', (v) => schema.addCity(v)),
      const SizedBox(height: 12),
      for (final c in schema.cities)
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.location_city_outlined),
          title: Text(c.name, style: TextStyle(fontSize: 14.5, color: p.text, fontWeight: FontWeight.w600)),
          subtitle: Text('${c.districts.length} маҳалла', style: TextStyle(fontSize: 12, color: p.muted)),
          children: [
            for (var i = 0; i < c.districts.length; i++)
              ListTile(
                dense: true,
                leading: Icon(Icons.place_outlined, size: 16, color: p.muted),
                title: Text(c.districts[i], style: TextStyle(fontSize: 13.5, color: p.text)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () async {
                      final v = await promptText(context, title: 'Тағйири маҳалла', initial: c.districts[i]);
                      if (v != null) schema.renameDistrict(c, i, v);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: p.brand),
                    onPressed: () => schema.removeDistrict(c, i),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: _addRow(p, 'Маҳаллаи нав...', (v) => schema.addDistrict(c, v), compact: true),
            ),
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Тағйири шаҳр'),
                onPressed: () async {
                  final v = await promptText(context, title: 'Тағйири шаҳр', initial: c.name);
                  if (v != null) schema.renameCity(c, v);
                },
              ),
              TextButton.icon(
                icon: Icon(Icons.delete_outline, size: 16, color: p.brand),
                label: Text('Хориҷ кардани шаҳр', style: TextStyle(color: p.brand)),
                onPressed: () => schema.removeCity(c),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
    ]);
  }

  // ----------------------------------------------------------------
  // SECTION 2: БАНДҲО / ЗЕРБАНДҲО / БРЕНДҲО (бемаҳдуд)
  // ----------------------------------------------------------------
  List<SchemaNode> _currentSiblings() {
    if (catPath.isEmpty) return schema.categories;
    return catPath.last.children;
  }

  Widget _catsSection(Palette p) {
    final siblings = _currentSiblings();
    final parent = catPath.isEmpty ? null : catPath.last;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        if (catPath.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => catPath.removeLast()),
          ),
        Expanded(child: Text(
          parent == null
              ? 'Бандҳои асосӣ (${schema.categories.length})'
              : '${parent.icon} ${parent.name} → ${siblings.length} зербанд',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text),
          overflow: TextOverflow.ellipsis,
        )),
      ]),
      const SizedBox(height: 8),
      _addRow(p, parent == null ? 'Банди нав (ном, иконка, ранг)...' : 'Зербанди нав...',
          (v) {
        if (parent == null) {
          _newCategoryDialog();
        } else {
          schema.addSubcategory(parent, v);
        }
      }),
      const SizedBox(height: 8),
      for (final n in siblings)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Text(n.icon, style: TextStyle(
                fontSize: 20, color: n.hidden ? Colors.grey : null)),
            title: Text(n.name,
                style: TextStyle(
                    fontSize: 14.5,
                    color: n.hidden ? Colors.grey : p.text,
                    fontWeight: FontWeight.w500,
                    decoration: n.hidden ? TextDecoration.lineThrough : null)),
            subtitle: Text(
              '${n.children.length} зербанд${n.colorHex != '#A62626' ? ' • ${n.colorHex}' : ''}',
              style: TextStyle(fontSize: 11.5, color: p.muted)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Ба боло',
                icon: const Icon(Icons.arrow_upward, size: 16),
                onPressed: () => schema.moveNode(siblings, n, -1),
              ),
              IconButton(
                tooltip: 'Ба поён',
                icon: const Icon(Icons.arrow_downward, size: 16),
                onPressed: () => schema.moveNode(siblings, n, 1),
              ),
              IconButton(
                tooltip: n.hidden ? 'Нишон додан' : 'Пинҳон кардан',
                icon: Icon(n.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
                onPressed: () => schema.toggleHideNode(n),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      final r = await _editNodeDialog(n);
                      if (r != null) schema.updateNodeStyle(n, icon: r.$1, colorHex: r.$2);
                      break;
                    case 'rename':
                      final name = await promptText(context, title: 'Тағйири ном', initial: n.name);
                      if (name != null) schema.renameNode(n, name);
                      break;
                    case 'enter':
                      if (n.children.isNotEmpty) setState(() => catPath.add(n));
                      break;
                    case 'addSub':
                      final name = await promptText(context, title: 'Зербанди нав дар «${n.name}»');
                      if (name != null) schema.addSubcategory(n, name);
                      break;
                    case 'delete':
                      schema.removeNode(siblings, n); // эълонҳо catPath-и матниро нигоҳ медоранд
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('🎨 Иконка ва ранг')),
                  const PopupMenuItem(value: 'rename', child: Text('✏️ Тағйири ном')),
                  const PopupMenuItem(value: 'addSub', child: Text('➕ Зербанди нав')),
                  if (n.children.isNotEmpty)
                    const PopupMenuItem(value: 'enter', child: Text('⤵️ Даромадан ба зербандҳо')),
                  const PopupMenuItem(value: 'delete', child: Text('🗑 Хориҷ кардан')),
                ],
              ),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      Text('Эълонҳо аз тағйирот бетаъсир monда мешаванд: catPath-и матнии онҳо нигоҳ дошта мешавад.',
          style: TextStyle(fontSize: 11.5, color: p.muted)),
    ]);
  }

  Future<(String, String)?> _editNodeDialog(SchemaNode n) async {
    String icon = n.icon;
    String color = n.colorHex;
    const icons = ['📦','🏠','🚗','📱','💻','🧸','👗','📺','🛋️','🔨','🎸','🐾','🛠️','🏬','🎁','🏢','💼','🚕','⭐','🎧'];
    const colors = ['#A62626','#D94141','#1B873F','#1565C0','#6A1B9A','#E65100','#00838F','#37474F'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Иконка ва ранг — ${n.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(
              spacing: 4, runSpacing: 4,
              children: [for (final i in icons)
                ChoiceChip(
                  label: Text(i, style: const TextStyle(fontSize: 16)),
                  selected: icon == i,
                  onSelected: (_) => setSt(() => icon = i),
                )],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [for (final c in colors)
                GestureDetector(
                  onTap: () => setSt(() => color = c),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: colorFromHex(c),
                      shape: BoxShape.circle,
                      border: color == c
                          ? Border.all(width: 3, color: Colors.black)
                          : null,
                    ),
                  ),
                )],
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Бекор')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.brand),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Нигоҳ доштан'),
            ),
          ],
        ),
      ),
    );
    return ok == true ? (icon, color) : null;
  }

  void _newCategoryDialog() {
    String icon = '📦';
    String color = '#A62626';
    final nameC = TextEditingController();
    const icons = ['📦','🏠','🚗','📱','💻','🧸','👗','📺','🛋️','🔨','🎸','🐾','🛠️','🏬','🎁','🏢','💼','⭐','🎧'];
    const colors = ['#A62626','#D94141','#1B873F','#1565C0','#6A1B9A','#E65100','#00838F','#37474F'];
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Банди нав'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Номи банд')),
            const SizedBox(height: 10),
            Wrap(spacing: 4, runSpacing: 4, children: [for (final i in icons)
              ChoiceChip(label: Text(i, style: const TextStyle(fontSize: 16)),
                selected: icon == i, onSelected: (_) => setSt(() => icon = i))]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [for (final c in colors)
              GestureDetector(
                onTap: () => setSt(() => color = c),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: colorFromHex(c), shape: BoxShape.circle,
                    border: color == c ? Border.all(width: 3, color: Colors.black) : null)),
              )]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Бекор')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.brand),
              onPressed: () {
                schema.addCategory(nameC.text, icon: icon, colorHex: color);
                Navigator.pop(ctx);
              },
              child: const Text('Илова'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // SECTION 3: ФАСЛҲО / РЕҶАҲО / ТАҶРИБА / ҲОЛАТ / МАЙДОНҲОИ ДИНАМИКӢ
  // ----------------------------------------------------------------
  Widget _fieldsSection(Palette p) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Гурӯҳҳои филтр (бемаҳдуд)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 4),
      Text('Илова, тағйир ва хориҷкунии Фасли корӣ, Реҷаи кор, Таҷриба, Ҳолат ва майдонҳои динамикӣ.',
          style: TextStyle(fontSize: 12, color: p.muted)),
      const SizedBox(height: 8),
      _addRow(p, 'Майдони динамикӣ-и нав (масалан: «Дастаи варзиш»)...', (v) => schema.addCustomField(v)),
      const SizedBox(height: 12),
      for (final f in schema.fields)
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(
            f.key == 'season' ? Icons.wb_sunny_outlined
            : f.key == 'schedule' ? Icons.schedule_outlined
            : f.key == 'experience' ? Icons.work_outline
            : f.key == 'condition' ? Icons.circle_outlined
            : Icons.tune,
            color: f.key.startsWith('custom') ? C.success : p.brand,
          ),
          title: Text(f.title, style: TextStyle(fontSize: 14.5, color: p.text, fontWeight: FontWeight.w600)),
          subtitle: Text('${f.values.length} арзиш${f.categoryPath != null ? ' • ${f.categoryPath}' : ''}',
              style: TextStyle(fontSize: 12, color: p.muted)),
          trailing: f.key.startsWith('custom')
              ? IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: p.brand),
                  onPressed: () => schema.removeCustomField(f.key),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _addRow(p, 'Арзиши нав...', (v) => schema.addFieldValue(f.key, v), compact: true),
            ),
            for (var i = 0; i < f.values.length; i++)
              ListTile(
                dense: true,
                leading: Icon(Icons.label_outline, size: 15, color: p.muted),
                title: Text(f.values[i], style: TextStyle(fontSize: 13.5, color: p.text)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    onPressed: () async {
                      final v = await promptText(context, title: 'Тағйири арзиш', initial: f.values[i]);
                      if (v != null) schema.renameFieldValue(f.key, i, v);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: p.brand),
                    onPressed: () => schema.removeFieldValue(f.key, i),
                  ),
                ]),
              ),
          ],
        ),
    ]);
  }

  // ----------------------------------------------------------------
  // SECTION 4: ИКОНКА / РАНГҲО / НОМ / SLOGAN / BANNERҲО
  // ----------------------------------------------------------------
  static const _brandColors = ['#A62626','#D94141','#1565C0','#1B873F','#6A1B9A','#E65100','#00838F','#37474F'];
  static const _logoEmblems = ['🧱','🏛️','🛡️','⚡'];

  Widget _visualSection(Palette p) {
    final v = schema.visual;
    final nameC = TextEditingController(text: v.appName);
    final sloganC = TextEditingController(text: v.slogan);
    final bannerTitleC = TextEditingController();
    final bannerSubC = TextEditingController();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Ном ва Slogan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 8),
      TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Номи барнома')),
      const SizedBox(height: 8),
      TextField(controller: sloganC, decoration: const InputDecoration(hintText: 'Slogan')),
      const SizedBox(height: 8),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: C.brand),
        onPressed: () {
          schema.setVisual(appName: nameC.text, slogan: sloganC.text);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Тамошӣ нигоҳ дошта шуд ✅ (баъди Нашр ба ҳама мерасад)')));
        },
        child: const Text('Нигоҳ доштан'),
      ),
      const SizedBox(height: 16),
      Text('Логотип (эмблема)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 8),
      Row(children: [
        for (var i = 0; i < _logoEmblems.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => schema.setVisual(logoStyle: i),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorFromHex(v.brandColorHex), C.brandHover]),
                  borderRadius: BorderRadius.circular(10),
                  border: v.logoStyle == i ? Border.all(width: 3, color: Colors.black87) : null,
                ),
                child: Center(child: Text(_logoEmblems[i], style: const TextStyle(fontSize: 22))),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Ранги асосӣ (Brand)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final c in _brandColors)
          GestureDetector(
            onTap: () => schema.setVisual(brandColorHex: c),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: colorFromHex(c),
                shape: BoxShape.circle,
                border: v.brandColorHex == c ? Border.all(width: 3, color: Colors.black87) : null,
              ),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Ранги аксент (Accent)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final c in _brandColors)
          GestureDetector(
            onTap: () => schema.setVisual(accentColorHex: c),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: colorFromHex(c),
                shape: BoxShape.circle,
                border: v.accentColorHex == c ? Border.all(width: 3, color: Colors.black87) : null,
              ),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Bannerҳо ва қисмҳои feed (${v.banners.length})',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
      const SizedBox(height: 8),
      for (var i = 0; i < v.banners.length; i++)
        ListTile(
          dense: true,
          leading: Text(v.banners[i].icon, style: const TextStyle(fontSize: 18)),
          title: Text(v.banners[i].title, style: TextStyle(fontSize: 13.5, color: p.text)),
          subtitle: v.banners[i].subtitle.isNotEmpty
              ? Text(v.banners[i].subtitle, style: TextStyle(fontSize: 11.5, color: p.muted))
              : null,
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: p.brand),
            onPressed: () => schema.removeBanner(i),
          ),
        ),
      _addRow(p, 'Номи banner-и нав...', (val) async {
        final sub = await promptText(context, title: 'Зернависи banner (ихтиёрӣ)');
        schema.addBanner(val, subtitle: sub ?? '', icon: '📣');
      }),
    ]);
  }

  // ----------------------------------------------------------------
  // SECTION 5: НАШР ВА АМНИЯТ (Publish + Change Credentials)
  // ----------------------------------------------------------------
  Widget _publishSection(Palette p) {
    final auth = SecurityAuthService.instance;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.success.withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.rocket_launch_outlined, color: C.success),
            const SizedBox(width: 8),
            Text('Instant OTA Publish', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: C.success)),
          ]),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            var publishedLine = '';
            final lp = schema.lastPublishedAt;
            if (lp != null) {
              final mm = lp.minute.toString().padLeft(2, '0');
              publishedLine = 'Охирин нашр: ${lp.hour}:$mm\n';
            }
            return Text(
              'Версияи schema: v${schema.schemaVersion}\n'
              '$publishedLine'
              'Дар воқеӣ: JSON ба Firestore doc `app_schema/live` меравад ва ҳар корбар '
              'banner-и «Навсозии нав баромад! • Насб кардан»-ро мебинад — БЕ Play Market.',
              style: TextStyle(fontSize: 12.5, color: p.textMid, height: 1.6),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.success),
              icon: const Icon(Icons.publish),
              label: const Text('Нашри тағйирот ба ҳама (Publish)', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () {
                schema.publish();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Schema v${schema.schemaVersion} нашр шуд 🚀')));
              },
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.brand.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.brand.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.security_outlined, color: p.brand),
            const SizedBox(width: 8),
            Text('Амнияти ҳисоби Админ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.brand)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Мухтасасҳо танҳо ҳамчун SHA-256 + salt захира шудаанд. Ҳеҷ гоҳ намоиш дода НАМЕШАВАНД. '
            'Барои иваз кардан пароли ҷорӣ ҳатман талаб мешавад.',
            style: TextStyle(fontSize: 12.5, color: p.textMid, height: 1.6),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: p.brand, side: BorderSide(color: p.brand)),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Ивази логин ва парол'),
              onPressed: () => _changeCredentialsDialog(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.brand),
              icon: const Icon(Icons.logout),
              label: const Text('Баромадан аз панели админ'),
              onPressed: () {
                auth.terminateAdminSession();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сессияи админ terminate шуд 🔒')));
              },
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text('Аудити админ:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: p.text)),
      const SizedBox(height: 4),
      ...auth.auditLog.take(10).map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '${e.at.hour}:${e.at.minute.toString().padLeft(2, '0')} • ${e.label}',
          style: TextStyle(fontSize: 11.5, color: p.muted)),
      )),
    ]);
  }

  Future<void> _changeCredentialsDialog() async {
    final curC = TextEditingController(), newLoginC = TextEditingController(),
        newPassC = TextEditingController(), confirmC = TextEditingController();
    final res = await showDialog<AuthResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ивази логин ва парол'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: curC,
            obscureText: true,
            autofillHints: null,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Пароли ҷорӣ (ҳатман)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newLoginC,
            autofillHints: null,
            enableSuggestions: false,
            decoration: const InputDecoration(hintText: 'Логини нав (≥4)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newPassC,
            obscureText: true,
            autofillHints: null,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Пароли нав (≥8)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmC,
            obscureText: true,
            autofillHints: null,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Тасдиқи пароли нав'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Бекор')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.brand),
            onPressed: () async {
              final r = await SecurityAuthService.instance.adminChangeCredentials(
                curC.text, newLoginC.text, newPassC.text, confirmC.text);
              if (ctx.mounted) Navigator.pop(ctx, r);
            },
            child: const Text('Иваз кардан'),
          ),
        ],
      ),
    );
    curC.clear(); newPassC.clear(); confirmC.clear(); // RAM wipe (DATA.md)
    if (res != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  // ----------------------------------------------------------------
  // Ҷузъҳои ёрирасон
  // ----------------------------------------------------------------
  Widget _addRow(Palette p, String hint, Future<void> Function(String) onAdd, {bool compact = false}) {
    final c = TextEditingController();
    return Row(children: [
      Expanded(
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: hint,
            isDense: compact,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 14),
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: p.brand),
        onPressed: () async {
          if (c.text.trim().isEmpty) return;
          await onAdd(c.text.trim());
          c.clear(); // RAM hygiene
        },
        child: const Text('➕'),
      ),
    ]);
  }
}

// ============================================================================
//  YОРИРАСОН: Dialog-и воридкунии матн
// ============================================================================
Future<String?> promptText(BuildContext context,
    {required String title, String hint = '', String initial = ''}) async {
  final c = TextEditingController(text: initial);
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint.isEmpty ? title : hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Бекор')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.brand),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  c.clear();
  return res;
}

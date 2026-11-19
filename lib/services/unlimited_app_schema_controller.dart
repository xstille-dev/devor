// ============================================================================
// unlimited_app_schema_controller.dart
// Девор — UnlimitedAppSchemaController (ChangeNotifier + JSON serialization)
// Муҳаррики Live Schema ва Builder-и бемаҳдуд:
//   1) Шаҳрҳо ва Маҳаллаҳо — бемаҳдуд (add/edit/delete)
//   2) Бандҳо / Зербандҳо / Брендҳо — бемаҳдуд (icon, rang, sort, hide, delete)
//   3) Фасли корӣ, Реҷаи кор, Таҷриба, Ҳолат + майдонҳои динамикӣ — бемаҳдуд
//   4) Иконка/рангҳо/ном/slogan + banner-ҳо ва қисмҳои нави feed — бемаҳдуд
//   5) Instant OTA Publish — version++ → banner-и «Навсозии нав баромад!»
//
// Persistence: FlutterSecureStorage (JSON) — омода барои Firebase Firestore /
// Remote Config sync (toJson/fromJson-и пурра; snapshot-ро дар doc-и
// `app_schema/live` навиштан кифоя аст — HACK.md §6, DATA.md §5).
// ============================================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// МОДЕЛҲО
// ---------------------------------------------------------------------------

/// Шаҳр бо маҳаллаҳои бемаҳдуд
class SchemaCity {
  String name;
  List<String> districts;
  SchemaCity(this.name, {List<String>? districts}) : districts = districts ?? [];

  Map<String, dynamic> toJson() => {'name': name, 'districts': districts};
  factory SchemaCity.fromJson(Map<String, dynamic> j) => SchemaCity(
        j['name'] as String,
        districts: List<String>.from(j['districts'] ?? []),
      );
}

/// Гиреҳи дарахти бандҳо (3-сатҳӣ ва бештар — бемаҳдуд)
class SchemaNode {
  String name;
  String icon;      // emoji (vector-icon art offline) — ё codepoint дар оянда
  String colorHex;  // '#A62626'
  bool hidden;
  List<SchemaNode> children;
  SchemaNode(this.name,
      {this.icon = '•', this.colorHex = '#A62626', this.hidden = false,
      List<SchemaNode>? children})
      : children = children ?? [];

  Map<String, dynamic> toJson() => {
        'name': name, 'icon': icon, 'colorHex': colorHex,
        'hidden': hidden,
        'children': children.map((c) => c.toJson()).toList(),
      };
  factory SchemaNode.fromJson(Map<String, dynamic> j) => SchemaNode(
        j['name'] as String,
        icon: (j['icon'] ?? '•') as String,
        colorHex: (j['colorHex'] ?? '#A62626') as String,
        hidden: (j['hidden'] ?? false) as bool,
        children: ((j['children'] ?? []) as List)
            .map((c) => SchemaNode.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );
}

/// Гурӯҳи майдонҳои динамикӣ (season / schedule / experience / condition / custom)
class SchemaFieldGroup {
  String key;        // 'season', 'schedule', 'experience', 'condition', 'custom_<ts>'
  String title;      // 'Фасли корӣ'
  List<String> values;
  String? categoryPath; // null = глобалӣ (ҳамаи бандҳо)
  SchemaFieldGroup(this.key, this.title, {List<String>? values, this.categoryPath})
      : values = values ?? [];

  Map<String, dynamic> toJson() =>
      {'key': key, 'title': title, 'values': values, 'categoryPath': categoryPath};
  factory SchemaFieldGroup.fromJson(Map<String, dynamic> j) => SchemaFieldGroup(
        j['key'] as String,
        j['title'] as String,
        values: List<String>.from(j['values'] ?? []),
        categoryPath: j['categoryPath'] as String?,
      );
}

/// Banner / promo-card / announcement-и feed
class SchemaBanner {
  String title, subtitle, colorHex, icon;
  SchemaBanner(this.title, {this.subtitle = '', this.colorHex = '#A62626', this.icon = '📣'});
  Map<String, dynamic> toJson() =>
      {'title': title, 'subtitle': subtitle, 'colorHex': colorHex, 'icon': icon};
  factory SchemaBanner.fromJson(Map<String, dynamic> j) => SchemaBanner(
        j['title'] as String,
        subtitle: (j['subtitle'] ?? '') as String,
        colorHex: (j['colorHex'] ?? '#A62626') as String,
        icon: (j['icon'] ?? '📣') as String,
      );
}

/// Тамошӣ (visual identity) барнома
class SchemaVisual {
  String appName, slogan;
  String brandColorHex, accentColorHex;
  int logoStyle; // 0..3 — emblems-и дарунсохт
  List<SchemaBanner> banners;
  SchemaVisual({
    this.appName = 'Девор',
    this.slogan = 'Бозори ройгони эълонҳои Тоҷикистон',
    this.brandColorHex = '#A62626',
    this.accentColorHex = '#1B873F',
    this.logoStyle = 0,
    List<SchemaBanner>? banners,
  }) : banners = banners ?? [];

  Map<String, dynamic> toJson() => {
        'appName': appName, 'slogan': slogan,
        'brandColorHex': brandColorHex, 'accentColorHex': accentColorHex,
        'logoStyle': logoStyle,
        'banners': banners.map((b) => b.toJson()).toList(),
      };
  factory SchemaVisual.fromJson(Map<String, dynamic> j) => SchemaVisual(
        appName: (j['appName'] ?? 'Девор') as String,
        slogan: (j['slogan'] ?? '') as String,
        brandColorHex: (j['brandColorHex'] ?? '#A62626') as String,
        accentColorHex: (j['accentColorHex'] ?? '#1B873F') as String,
        logoStyle: (j['logoStyle'] ?? 0) as int,
        banners: ((j['banners'] ?? []) as List)
            .map((b) => SchemaBanner.fromJson(Map<String, dynamic>.from(b)))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// SEEDS-И ПЕШФАРЗ (танҳо барои аввалин иҷро — мухтасасҳои админ НЕСТАНД)
// ---------------------------------------------------------------------------
List<SchemaCity> defaultCities() => [
      SchemaCity('Душанбе', districts: [
        'Исмоили Сомонӣ', 'Сино', 'Фирдавсӣ', 'Шоҳмансур', 'Марказ',
        '33 мкр', '82 мкр', 'Зарафшон', 'Садбарг', 'Профсоюз',
      ]),
      SchemaCity('Хуҷанд', districts: ['Хуҷанд-марказ']),
      SchemaCity('Бохтар', districts: ['Бохтар-марказ']),
      SchemaCity('Кӯлоб', districts: ['Марказ']),
      SchemaCity('Истаравшан', districts: ['Марказ']),
      SchemaCity('Ваҳдат', districts: ['Марказ']),
      SchemaCity('Ҳисор', districts: ['Марказ']),
      SchemaCity('Турсунзода', districts: ['Марказ']),
      SchemaCity('Панҷакент', districts: ['Марказ']),
      SchemaCity('Исфара', districts: ['Марказ']),
      SchemaCity('Конибодом', districts: ['Марказ']),
      SchemaCity('Хоруғ', districts: ['Марказ']),
      SchemaCity('Рашт', districts: ['Марказ']),
      SchemaCity('Муғоб', districts: ['Марказ']),
      SchemaCity('Ҳамаи Тоҷикистон'),
    ];

const _carBrands = [
  'Toyota', 'Mercedes-Benz', 'Hyundai', 'Opel', 'BMW', 'Lexus', 'GAC', 'Kia', 'BYD',
  'Daewoo', 'Lada (ВАЗ)', 'Dongfeng', 'Volkswagen', 'Land Rover', 'Honda', 'Nissan',
  'Chevrolet', 'Changan', 'Leapmotor', 'Zeekr', 'Tesla', 'LiXiang', 'Audi', 'Mazda',
  'Mitsubishi', 'Skoda', 'Porsche', 'Тамғаи дигар',
];
const _phoneBrands = [
  'Apple', 'Samsung', 'Xiaomi', 'Huawei (Honor)', 'Tecno', 'Infinix', 'Novey', 'Itel',
  'Realme', 'Vivo', 'Oppo', 'Google', 'OnePlus', 'Vertu', 'ZTE', 'Nothing Phone', 'ASUS',
];
const _rooms = ['1-хонагӣ', '2-хонагӣ', '3-хонагӣ', '4-хонагӣ', '5-хонагӣ', '6-хонагӣ ва зиёда'];

SchemaNode _s(String name, {String icon = '•', List<SchemaNode> children = const []}) =>
    SchemaNode(name, icon: icon, children: children);

List<SchemaNode> defaultCategories() => [
      _s('Навсохтҳо', icon: '🏢', children: [
        _s('Навсохтҳои дар ҷараёни сохтмон'),
        _s('Навсохтҳои омода'),
        _s('Навсохтҳои иҷорагӣ'),
      ]),
      _s('Амволи ғайриманқул', icon: '🏠', children: [
        _s('Фурӯши хонаҳо', children: [for (final r in _rooms) _s(r)]),
        _s('Иҷораи хонаҳо', children: [for (final r in _rooms) _s(r)]),
        _s('Фурӯши ҳавлӣ ва дача'), _s('Иҷораи ҳавлӣ'),
        _s('Иҷораи якшабонарӯзаи хона, ҳавлӣ'), _s('Иҷораи ҳуҷраҳо'),
        _s('Фурӯши манзил барои корхона'), _s('Иҷораи манзил барои корхона'),
        _s('Фурӯш, иҷораи гараж ва таваққуфгоҳ'), _s('Фурӯши бинои алоҳида истода'),
        _s('Фурӯш ва иҷораи сохтмон бо замини наздиҳавлигӣ'), _s('Иҷораи дача'),
        _s('Фурӯш, иҷораи вагон ва хоначаи муваққатӣ'),
      ]),
      _s('Нақлиёт', icon: '🚗', children: [
        _s('Автомобили сабукрав', children: [for (final b in _carBrands) _s(b)]),
        _s('Лавозимот ва қисмҳои нақлиёт', children: [
          _s('Қисмҳои эҳтиётии автомобил'), _s('Лавозимот барои автомобил'),
          _s('Шина ва дискаҳо'), _s('Қисмҳои эҳтиётии техникаи махсус ва кишоварзӣ'),
          _s('Автосадо, видео'), _s('Қисмҳои эҳтиётии мототсикл'),
          _s('Лавозимот барои мототсикл'), _s('Равған ва автохимия'),
        ]),
        _s('Мото нақлиёт'),
        _s('Нақлиёти тиҷоратӣ', children: [
          _s('Техникаи сохтмонӣ ва махсус'), _s('Нақлиёти боркаш'),
          _s('Техникаи кишоварзӣ'), _s('Нақлиёти тиҷоратии сабук'), _s('Автобусҳо'),
        ]),
        _s('Хизматгузорӣ ва таъмири нақлиёт'), _s('Ядак ва контейнерҳо'),
        _s('Дигар нақлиёт', children: [
          _s('Аробачаи маъюбон'), _s('Гироскутерҳо'), _s('Нақлиёти обӣ'),
        ]),
      ]),
      _s('Ҷои кор', icon: '💼', children: [
        _s('Рестораторҳо, ошпазҳо, пешхизматҳо'), _s('Тиҷорат, савдои чакана'),
        _s('Кормандони гуногунсоҳа'), _s('Ҳисобдорӣ, молия, ҳуқуқшиносҳо'),
        _s('Кормандони хонагӣ, хизматрасонӣ'), _s('Нақлиёт, логистика, анбор'),
        _s('Кормандони маъмурӣ'), _s('Маориф, фарҳанг, санъат'),
        _s('IT, телеком, компютерҳо'), _s('Тиб, фарматсия'),
        _s('Маркетинг, таблиғот, ороиш'), _s('Истеҳсолот, энергетика'),
        _s('Бонкҳо, суғурта, лизинг'), _s('Роҳбарон'), _s('Сохтмон, амволи ғайриманқул'),
        _s('Шӯъбаи кадрҳо'), _s('Зебой, фитнес, варзиш'), _s('Оҷонсии кадрҳо'),
        _s('Кор дар хориҷа'), _s('Мудофиа, амният'), _s('Оғози мансаб, донишҷӯён'),
        _s('Саёҳӣ, меҳмонхонаҳо'), _s('Шуғли қисман'), _s('ВАО, нашриётҳо'),
        _s('Дигар соҳаи шуғл'),
      ]),
      _s('Телефонҳо ва алоқа', icon: '📱', children: [
        _s('Телефонҳои мобилӣ', children: [for (final b in _phoneBrands) _s(b)]),
        _s('Лавозимот барои телефон', children: [
          _s('Гӯшмонакҳо'), _s('Аккумулятори берунӣ'), _s('Смарт-соатҳо'),
          _s('Лавозимоти наворбардорӣ'), _s('Асбоби заряддиҳӣ'), _s('Ғилофҳо'),
          _s('Лавозимотҳо'), _s('Дорандагони телефон'), _s('Геймпад, триггер'),
          _s('Корти хотира'), _s('Data-ноқилҳо'), _s('Колбад / панел'),
          _s('Плёнка ва шишаҳои ҳифозатӣ'),
        ]),
        _s('Қисмҳо ва асбобҳо барои таъмири телефонҳо'), _s('Телефонҳои статсионарӣ'),
        _s('Дигар таҷҳизоти алоқа'), _s('Хизматгузорӣ ва таъмири телефонҳо'),
      ]),
      _s('Олами кӯдакон', icon: '🧸', children: [
        _s('Мебели кӯдакона', children: [
          _s('Рахти хоб'), _s('Ҷевонҳо, комод, рафчаҳо'), _s('Гаҳвораҳо'),
          _s('Миз, курсиҳо'), _s('Шезлонг'), _s('Курсиҳо барои хурокхӯрӣ'),
          _s('Маҷмӯи мебели кӯдакона'),
        ]),
        _s('Нақлиёти кӯдакона', children: [
          _s('Мошини кӯдакона'), _s('Велосипеди кӯдакона'), _s('Роликҳо, самокатҳо'),
          _s('Мототсикли кӯдакона'), _s('Роҳгардаки кӯдакона'), _s('Велоколяска'),
        ]),
        _s('Арғунчак ва аробачаҳои кӯдакона', children: [
          _s('Аробачаҳои кӯдакона'), _s('Арғунчакҳо'),
        ]),
        _s('Пойафзоли кӯдакона', children: [_s('Барои духтарон'), _s('Барои писарон')]),
        _s('Либоси кӯдакона'), _s('Бозичаҳо'), _s('Молҳо барои мактаббачагон'),
        _s('Молҳо барои оббозии кӯдакон'), _s('Лавозимоти бистарӣ'),
        _s('Молҳо барои модарон'), _s('Молҳо барои хӯрокдиҳӣ'),
        _s('Курсии кӯдакона барои мошин'), _s('Соатҳои кӯдакона'),
        _s('Дигар молҳои кӯдакона'),
      ]),
      _s('Либос ва ашёҳои шахсӣ', icon: '👗', children: [
        _s('Атриёт ва косметика'), _s('Либоси занона'), _s('Соатҳо ва зинат'),
        _s('Либоси мардона'), _s('Пойафзол'), _s('Ҷомадонҳо, ҷузвадонҳо, клатчҳо'),
        _s('Лавозимотҳо, шарфҳо, каллапӯшҳо'), _s('Барои тӯй'),
        _s('Матоъ ва лавозимот барои дӯхтани либос'), _s('Иҷораи либос'),
        _s('Молҳои гумшуда ва ёфтшуда'), _s('Дигар молҳо'),
      ]),
      _s('Компютерҳо ва таҷҳизоти идоравӣ', icon: '💻', children: [
        _s('Лавозимотҳо ва қисмҳои эҳтиётӣ'), _s('Барномаҳо ва бозиҳо'),
        _s('Планшетҳо ва китобҳои электронӣ'), _s('Ноутбукҳо'),
        _s('Модемҳо ва таҷҳизоти шабакавӣ'), _s('Дастгоҳи бозикунӣ'),
        _s('Компютерҳои шахсӣ'), _s('Мониторҳо ва проекторҳо'),
        _s('Принтерҳо ва сканерҳо'), _s('Таъмир'), _s('Серверҳо'),
        _s('Дигар таҷҳизот'),
      ]),
      _s('Электроника ва таҷҳизоти маишӣ', icon: '📺', children: [
        _s('Таҷҳизот барои манзил ва ошхона'), _s('Таҷҳизоти иқлимӣ'),
        _s('Барои нигоҳубини шахсӣ'), _s('TV, DVD ва видео'),
        _s('Системаҳои назорати видеоӣ, амният ва "Хонаи доно"'),
        _s('Аудио ва стерео'), _s('Таҷҳизот ва лавозимоти тиббӣ'),
        _s('Лавозимотҳо'), _s('Суратгирак ва видеокамераҳо'),
        _s('Қисмҳои радио ва электронӣ'), _s('Дигар таҷҳизот'),
      ]),
      _s('Барои манзил', icon: '🛋️', children: [
        _s('Мебел'), _s('Молҳои бофандагӣ ва ороишоти дохили хона'),
        _s('Зарфҳо ва лавозимоти ошхона'), _s('Ашёи рӯзғор ва кимиёи маишӣ'),
        _s('Боғ ва обчакорӣ'), _s('Сейфҳо'), _s('Молҳои идона'),
        _s('Молҳои канселярӣ'), _s('Маҳсулоти хӯрокворӣ'),
        _s('Дигар молҳо барои манзил'),
      ]),
      _s('Сохтмон, ашёи хом ва таъмир', icon: '🔨', children: [
        _s('Масолеҳи сохтмонӣ ва ороишӣ'), _s('Асбоби электрикӣ'), _s('Асбоби дастӣ'),
      ]),
      _s('Шавқу завқ, мусиқӣ ва варзиш', icon: '🎸', children: [
        _s('Бозичаҳои бузургсолон'), _s('Китобҳо ва журналҳо'), _s('Мусиқӣ'),
        _s('Варзиш'), _s('Велосипедҳо'), _s('Олами бозиҳо'),
        _s('Маҷлисҳо ва сайёҳат'), _s('Дигар шавқу завқ'),
      ]),
      _s('Ҳайвонот ва растаниҳо', icon: '🐾', children: [
        _s('Сагҳо'), _s('Пушакҳо'), _s('Паррандаҳо'), _s('Моҳӣ'),
        _s('Ҷонварҳои хона', children: [_s('Хирсҳо'), _s('Харгӯшҳо')]),
        _s('Молҳои хайвонот'), _s('Хизматрасониҳо барои ҳайвонот'),
        _s('Хӯроки ҳайвонот'), _s('Растаниҳо'), _s('Дигар ҷонварон'),
      ]),
      _s('Хизматрасониҳо', icon: '🛠️', children: [
        _s('Таъмир ва сохтмон'), _s('Ороиш ва либосшӯй'), _s('Ташхис ва таъмири техникӣ'),
        _s('Омӯзиш ва дирёзҳо'), _s('Нақлиёт ва сайёҳат'), _s('Ороиши тӯй ва ҷашнҳо'),
        _s('Фотосуратгирӣ ва видео'), _s('Ҳисобдорӣ ва ҳуқуқ'), _s('Интернет ва телеком'),
        _s('Тандурустӣ'), _s('Хизматрасониҳои дигар'),
      ]),
      _s('Барои тиҷорат', icon: '🏬', children: [
        _s('Биноҳо ва дуконҳо'), _s('Таҷҳизоти тиҷоратӣ'), _s('Маҳсулот ва мол'),
        _s('Маводи ашёи хом'), _s('Стиролҳо ва тагҳо'), _s('Дигар тиҷорат'),
      ]),
      _s('Ройгон медиҳам', icon: '🎁', children: [
        _s('Мебел ва ашёи хона'), _s('Либос ва пойафзол'), _s('Бозичаҳо'),
        _s('Таҷҳизот'), _s('Китобҳо'), _s('Дигар молҳои ройгон'),
      ]),
    ];

List<SchemaFieldGroup> defaultFields() => [
      SchemaFieldGroup('season', 'Фасли корӣ', values: [
        'Баҳорӣ', 'Тобистона', 'Тирамоҳӣ', 'Зимистона', 'Солона', 'Мавсимӣ',
      ]),
      SchemaFieldGroup('schedule', 'Реҷаи кор', values: [
        'Рӯзона', 'Реҷаи озод', 'Мавсимӣ, тақвимӣ', 'Фосилавӣ',
        'Якҷоякунӣ', 'Шабона', 'Берун аз ҷойи истиқомат', 'Муваққатӣ',
      ]),
      SchemaFieldGroup('experience', 'Таҷриба', values: [
        'Дилхоҳ', 'Бе таҷриба', 'аз 1 сол', 'аз 3 сол', 'аз 5 сол',
      ]),
      SchemaFieldGroup('condition', 'Ҳолат', values: [
        'Нав', 'Дар ҳолати хуб', 'Истифодашуда', 'Барои қисмҳои эҳтиётӣ',
      ]),
    ];

// ---------------------------------------------------------------------------
// КОНТРОЛЛЕР — бемаҳдуд CRUD + persist + OTA publish
// ---------------------------------------------------------------------------
class UnlimitedAppSchemaController extends ChangeNotifier {
  UnlimitedAppSchemaController() {
    _load();
  }

  static const String _storageKey = 'devor_unlimited_schema_v1';

  final FlutterSecureStorage _vault = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.whenUnlocked),
  );

  List<SchemaCity> cities = [];
  List<SchemaNode> categories = [];
  List<SchemaFieldGroup> fields = [];
  SchemaVisual visual = SchemaVisual();
  int schemaVersion = 1;
  int appliedVersion = 1; // version-и насбшуда дар ин дастгоҳ (OTA)
  DateTime? lastPublishedAt;

  bool get hasUpdate => schemaVersion > appliedVersion;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ---------- СЕРИАЛИЗАТСИЯ (Firestore / Remote Config ready) ----------
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'lastPublishedAt': lastPublishedAt?.toIso8601String(),
        'cities': cities.map((c) => c.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'fields': fields.map((f) => f.toJson()).toList(),
        'visual': visual.toJson(),
      };

  void fromJson(Map<String, dynamic> j) {
    cities = ((j['cities'] ?? []) as List)
        .map((c) => SchemaCity.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    categories = ((j['categories'] ?? []) as List)
        .map((c) => SchemaNode.fromJson(Map<String, dynamic>.from(c)))
        .toList();
    fields = ((j['fields'] ?? []) as List)
        .map((f) => SchemaFieldGroup.fromJson(Map<String, dynamic>.from(f)))
        .toList();
    visual = SchemaVisual.fromJson(Map<String, dynamic>.from(j['visual'] ?? {}));
    schemaVersion = (j['schemaVersion'] ?? 1) as int;
    lastPublishedAt = j['lastPublishedAt'] != null
        ? DateTime.tryParse(j['lastPublishedAt'] as String)
        : null;
  }

  Future<void> _load() async {
    final raw = await _vault.read(key: _storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        fromJson(jsonDecode(raw) as Map<String, dynamic>);
        final applied = int.tryParse(await _vault.read(key: '$_storageKey#applied') ?? '') ?? schemaVersion;
        appliedVersion = applied;
      } catch (_) {
        _seed(); // schema-и вайрон → seed-и пешфарз
      }
    } else {
      _seed();
    }
    _loaded = true;
    notifyListeners();
  }

  void _seed() {
    cities = defaultCities();
    categories = defaultCategories();
    fields = defaultFields();
    visual = SchemaVisual();
    schemaVersion = 1;
  }

  Future<void> _persist() async {
    await _vault.write(key: _storageKey, value: jsonEncode(toJson()));
    await _vault.write(key: '$_storageKey#applied', value: appliedVersion.toString());
  }

  void _changed() {
    _persist();
    notifyListeners();
  }

  // ---------- ДАСТРАСӢ ----------
  List<String> get cityNames => cities.map((c) => c.name).toList();

  /// Маҳаллаҳои шаҳри ҷорӣ (ё маҷмӯи ҳама — барои «Ҳамаи Тоҷикистон»)
  List<String> districtsFor(String cityName) {
    if (cityName == 'Ҳамаи Тоҷикистон') {
      final all = <String>{};
      for (final c in cities) all.addAll(c.districts);
      return all.toList();
    }
    return cities.firstWhere((c) => c.name == cityName,
        orElse: () => SchemaCity(cityName)).districts;
  }

  SchemaFieldGroup? field(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  List<SchemaFieldGroup> get customFields =>
      fields.where((f) => f.key.startsWith('custom')).toList();

  List<SchemaNode> get visibleCategories {
    final v = categories.where((c) => !c.hidden).toList();
    return v;
  }

  // ================================================================
  //  1) ШАҲРҲО ВА МАҲАЛЛАҲО — бемаҳдуд
  // ================================================================
  void addCity(String name) {
    if (name.trim().isEmpty) return;
    cities.add(SchemaCity(name.trim()));
    _changed();
  }

  void renameCity(SchemaCity city, String newName) {
    if (newName.trim().isEmpty) return;
    city.name = newName.trim();
    _changed();
  }

  void removeCity(SchemaCity city) {
    cities.remove(city);
    _changed();
  }

  void addDistrict(SchemaCity city, String name) {
    if (name.trim().isEmpty || city.districts.contains(name.trim())) return;
    city.districts.add(name.trim());
    _changed();
  }

  void renameDistrict(SchemaCity city, int index, String newName) {
    if (newName.trim().isEmpty) return;
    if (index < 0 || index >= city.districts.length) return;
    city.districts[index] = newName.trim();
    _changed();
  }

  void removeDistrict(SchemaCity city, int index) {
    if (index < 0 || index >= city.districts.length) return;
    city.districts.removeAt(index);
    _changed();
  }

  // ================================================================
  //  2) БАНДҲО / ЗЕРБАНДҲО / БРЕНДҲО — бемаҳдуд
  // ================================================================
  void addCategory(String name, {String icon = '📦', String colorHex = '#A62626'}) {
    if (name.trim().isEmpty) return;
    categories.add(SchemaNode(name.trim(), icon: icon, colorHex: colorHex));
    _changed();
  }

  void addSubcategory(SchemaNode parent, String name) {
    if (name.trim().isEmpty) return;
    parent.children.add(SchemaNode(name.trim()));
    _changed();
  }

  void addThirdLevel(SchemaNode parent, SchemaNode sub, String name) {
    if (name.trim().isEmpty) return;
    sub.children.add(SchemaNode(name.trim()));
    _changed();
  }

  void renameNode(SchemaNode node, String newName) {
    if (newName.trim().isEmpty) return;
    node.name = newName.trim();
    _changed();
  }

  void updateNodeStyle(SchemaNode node, {String? icon, String? colorHex}) {
    if (icon != null) node.icon = icon;
    if (colorHex != null) node.colorHex = colorHex;
    _changed();
  }

  void toggleHideNode(SchemaNode node) {
    node.hidden = !node.hidden;
    _changed();
  }

  /// Reorder — муҳаррики sort: ивази ҷои ду гиреҳ дар рӯйхати волидайн
  void moveNode(List<SchemaNode> siblings, SchemaNode node, int delta) {
    final i = siblings.indexOf(node);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= siblings.length) return;
    siblings.removeAt(i);
    siblings.insert(j, node);
    _changed();
  }

  /// Хориҷкунӣ бе вайрони эълонҳо: эълонҳо catPath-и матнии худро нигоҳ
  /// медоранд — танҳо навигация тағйир меёбад (без breaking changes).
  void removeNode(List<SchemaNode> siblings, SchemaNode node) {
    siblings.remove(node);
    _changed();
  }

  // ================================================================
  //  3) ФАСЛҲО / РЕҶАҲО / ТАҶРИБА / ҲОЛАТ / МАЙДОНҲОИ ДИНАМИКӢ — бемаҳдуд
  // ================================================================
  void addFieldValue(String key, String value) {
    final f = field(key);
    if (f == null || value.trim().isEmpty || f.values.contains(value.trim())) return;
    f.values.add(value.trim());
    _changed();
  }

  void renameFieldValue(String key, int index, String newValue) {
    final f = field(key);
    if (f == null || newValue.trim().isEmpty) return;
    if (index < 0 || index >= f.values.length) return;
    f.values[index] = newValue.trim();
    _changed();
  }

  void removeFieldValue(String key, int index) {
    final f = field(key);
    if (f == null) return;
    if (index < 0 || index >= f.values.length) return;
    f.values.removeAt(index);
    _changed();
  }

  /// Майдон-и динамик-и нав (чипҳои филтрӣ барои ягон банд ё глобалӣ)
  void addCustomField(String title, {String? categoryPath}) {
    if (title.trim().isEmpty) return;
    fields.add(SchemaFieldGroup(
      'custom_${DateTime.now().millisecondsSinceEpoch}',
      title.trim(),
      categoryPath: categoryPath,
    ));
    _changed();
  }

  void removeCustomField(String key) {
    fields.removeWhere((f) => f.key == key);
    _changed();
  }

  // ================================================================
  //  4) ИКОНКА / РАНГҲО / НОМ / SLOGAN / BANNERҲО — бемаҳдуд
  // ================================================================
  void setVisual({String? appName, String? slogan, String? brandColorHex,
      String? accentColorHex, int? logoStyle}) {
    if (appName != null && appName.trim().isNotEmpty) visual.appName = appName.trim();
    if (slogan != null) visual.slogan = slogan.trim();
    if (brandColorHex != null) visual.brandColorHex = brandColorHex;
    if (accentColorHex != null) visual.accentColorHex = accentColorHex;
    if (logoStyle != null) visual.logoStyle = logoStyle;
    _changed();
  }

  void addBanner(String title, {String subtitle = '', String colorHex = '#A62626',
      String icon = '📣'}) {
    if (title.trim().isEmpty) return;
    visual.banners.add(SchemaBanner(title.trim(),
        subtitle: subtitle.trim(), colorHex: colorHex, icon: icon));
    _changed();
  }

  void removeBanner(int index) {
    if (index < 0 || index >= visual.banners.length) return;
    visual.banners.removeAt(index);
    _changed();
  }

  // ================================================================
  //  5) INSTANT OTA PUBLISH
  // ================================================================
  /// Version++ → ҳар дастгоҳ banner-и «Навсозии нав баромад! • Насб кардан»
  /// мебинад. Дар воқеӣ: JSON-и schema ба Firestore doc `app_schema/live`
  /// навишта мешавад — корбарон бо огоҳии next-launch мегиранд (бе Play Market).
  void publish() {
    schemaVersion++;
    lastPublishedAt = DateTime.now();
    _changed();
  }

  /// «Насб кардан» — корбар schema-и навро аз худи феъл истифода мебарад.
  void applyUpdate() {
    appliedVersion = schemaVersion;
    _changed();
  }
}

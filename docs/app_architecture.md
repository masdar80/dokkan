# 🏗️ هيكلية التطبيق (App Architecture)

سيعتمد تطبيق "دكان" على بنية برمجية منظمة تسمح بفصل منطق العمل (Business Logic) عن واجهات المستخدم، مما يسهل عملية الصيانة والتطوير.

---

## 📂 تقسيم المجلدات (Folder Structure)

```text
lib/
├── core/                  # الثوابت، التنسيقات، والوظائف العامة
│   ├── constants/         # ألوان، نصوص ثابته، روابط
│   ├── theme/             # تصميم الواجهات (App Theme)
│   └── utils/             # أدوات مساعدة (Currency Formatter, Date Utils)
├── data/                  # طبقة البيانات
│   ├── datasources/       # التعامل مع SQLite (Local DB) و الـ Web Scraping
│   ├── models/            # نماذج البيانات (To/From JSON/Map)
│   └── repositories/      # تنفيذ مستودعات البيانات
├── domain/                # طبقة المنطق (Business Logic)
│   ├── entities/          # الكائنات الأساسية (Product, Sale, Batch)
│   └── repositories/      # تعريف واجهات المستودعات (Interfaces)
├── providers/             # إدارة حالة التطبيق (State Management)
│   ├── exchange_rate_provider.dart
│   ├── inventory_provider.dart
│   └── sales_provider.dart
└── presentation/          # طبقة الواجهات (UI)
    ├── screens/           # الصفحات الرئيسية (Home, Sales, Inventory)
    └── widgets/           # المكونات الصغيرة القابلة لإعادة الاستخدام
```

---

## 🛠️ التقنيات المستخدمة (Tech Stack)

*   **State Management**: `Provider` أو `Riverpod` (لسهولة التعامل مع الحالة والبيانات المشتركة).
*   **Local Database**: `sqflite` (لتخزين البيانات محلياً بشكل علائقي).
*   **Web Scraping**: `http` لجلب الصفحة و `html` لمعالجتها.
*   **PDF Generation**: `pdf` و `printing` لتصدير التقارير.
*   **Localization**: `flutter_localizations` لدعم اللغة العربية (RTL).

---

## 🔄 تدفق البيانات (Data Flow)

1.  **سعر الصرف**:
    *   عند الفتح: يقوم `ExchangeRateService` بجلب البيانات.
    *   يتم تمرير القيمة لـ `ExchangeRateProvider`.
    *   يطلب الـ `Provider` من الواجهة عرض "تنبيه موافقة" للمستخدم.
    *   بعد الموافقة، يتم تحديث الحالة وتخزين السعر في `sqflite`.

2.  **عملية البيع**:
    *   تختار الواجهة المنتج.
    *   يقوم `InventoryProvider` بحساب الكمية المتاحة عبر `Batches`.
    *   عند التأكيد، يتم خصم الكمية من أقدم `Batch` (نظام FIFO) وتسجيل العملية.

---

## 🧩 المكونات البرمجية الرئيسية (Key Components)

### 1. DatabaseHelper
كلاس أحادي (Singleton) مسؤول عن إنشاء قاعدة البيانات والجداول وتنفيذ استعلامات الـ SQL.

### 2. ScrapingService
مسؤول عن الاتصال بموقع `sp-today.com` وتحليل كود الـ HTML لاستخراج قيمة "Sell".

### 3. FIFO Logic Handler
دالة برمجية داخل `SalesRepository` تقوم بالبحث في الدفعات وتوزيع الكمية المبيعة على الدفعات المتاحة بالتسلسل الزمني.

# 🗄️ هيكلية قاعدة البيانات (Database Schema)

هذا المستند يوضح الجداول والعلاقات اللازمة لتشغيل تطبيق "دكان" مع ضمان دقة الحسابات المالية ونظام FIFO.

---

## 📊 مخطط العلاقات (ER Diagram)

```mermaid
erDiagram
    PRODUCTS ||--o{ BATCHES : "has"
    PRODUCTS ||--o{ SALE_ITEMS : "sold_in"
    SALES ||--o{ SALE_ITEMS : "contains"
    PARTNERS ||--o{ CAPITAL_LOG : "contributes"

    PRODUCTS {
        int id PK
        string name
        double current_quantity
        double default_sell_price_syp
        datetime created_at
    }

    BATCHES {
        int id PK
        int product_id FK
        double initial_quantity
        double remaining_quantity
        double purchase_price_syp
        double exchange_rate
        double cost_usd
        datetime purchase_date
    }

    SALES {
        int id PK
        datetime sale_date
        double total_amount_syp
        double total_amount_usd
        double exchange_rate
    }

    SALE_ITEMS {
        int id PK
        int sale_id FK
        int product_id FK
        double quantity
        double sell_price_syp
        double cost_usd_at_sale
        double profit_usd
    }

    SETTINGS {
        string key PK
        string value
    }

    PARTNERS {
        int id PK
        string name
        double percentage
        double capital_usd
    }
```

---

## 📝 تفاصيل الجداول

### 1. جدول التصنيفات (categories)
| الحقل | النوع | الوصف |
| :--- | :--- | :--- |
| id | INTEGER | مفتاح أساسي تلقائي |
| name | TEXT | اسم التصنيف (فريد) |

### 2. جدول المواد (products)
| الحقل | النوع | الوصف |
| :--- | :--- | :--- |
| id | INTEGER | مفتاح أساسي تلقائي |
| code | TEXT | رمز المادة (فريد) |
| name | TEXT | اسم المادة (فريد) |
| category_id | INTEGER | ربط بالتصنيف |
| current_quantity | REAL | الكمية الحالية المتوفرة |
| default_sell_price_syp | REAL | سعر البيع الافتراضي بالليرة |
| created_at | TEXT | تاريخ الإضافة |

### 3. جدول الدفعات (Batches)
**أهم جدول في النظام**، حيث يسمح بتطبيق نظام FIFO. كل عملية شراء تخزن كدفعة مستقلة بتكلفتها الخاصة.

| الحقل | النوع | الوصف |
| :--- | :--- | :--- |
| `id` | Integer | مفتاح أساسي. |
| `product_id` | FK | ربط مع جدول المواد. |
| `initial_quantity` | Double | الكمية الأصلية عند الشراء. |
| `remaining_quantity` | Double | الكمية المتبقية حالياً من هذه الدفعة. |
| `purchase_price_syp` | Double | سعر الشراء بالليرة السورية. |
| `exchange_rate` | Double | سعر الصرف وقت الشراء. |
| `cost_usd` | Double | التكلفة بالدولار (تحسب عند الإدخال: SYP / Rate). |

### 3. جدول المبيعات (Sales)
يوثق عملية البيع الكلية (الفاتورة).

| الحقل | النوع | الوصف |
| :--- | :--- | :--- |
| `id` | Integer | مفتاح أساسي. |
| `total_amount_syp` | Double | إجمالي الفاتورة بالليرة. |
| `total_amount_usd` | Double | إجمالي الفاتورة بالدولار. |
| `exchange_rate` | Double | سعر الصرف المستخدم وقت البيع. |

### 4. جدول تفاصيل المبيعات (SaleItems)
يوثق كل مادة داخل عملية البيع مع حساب الربح المحقق لها بالدولار.

| الحقل | النوع | الوصف |
| :--- | :--- | :--- |
| `cost_usd_at_sale` | Double | التكلفة الفعلية بالدولار (تؤخذ من الدفعات المستخدمة). |
| `profit_usd` | Double | صافي الربح بالدولار لهذه العملية. |

---

## ⚙️ ملاحظات تقنية
1. **نظام FIFO**: عند البيع، يقوم النظام بالبحث في جدول `Batches` عن أقدم دفعة لنفس المادة تحتوي على `remaining_quantity > 0` ويخصم منها أولاً.
2. **سعر الصرف**: يتم تخزين سعر الصرف الحالي في جدول `Settings` تحت مفتاح `current_exchange_rate`.

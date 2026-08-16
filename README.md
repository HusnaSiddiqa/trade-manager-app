# Trade Manager — Shop ERP

A Flutter + Firebase ERP application for managing day-to-day operations of a building materials shop — sales, purchases, rentals, customer/supplier accounts, and financial reports, all in one place.

---

## Features

### 📊 Dashboard
- Key stats (revenue, sales count, dues) filtered by **Today / This Week / This Month**
- Active rentals and customers with pending dues at a glance
- Quick-action buttons to log a sale, purchase, rental, or expense without navigating away

### 🧾 Sales
- Create sales bills with multiple line items and quantities
- Auto-calculates totals; supports partial payment and credit sales
- PDF bill generation — download or share directly from the app

### 👥 Customers
- Customer directory with contact details
- Per-customer **ledger** showing all transactions and outstanding balance
- **Due analysis** screen listing every customer with a pending amount

### 📦 Products
- Product catalogue with stock tracking
- **Product analytics** — sales volume and revenue per product over time

### 🛒 Purchases
- Log purchases from suppliers with itemised entries
- Supplier ledger and **supplier dues** screen

### 🤝 Rentals
- Manage rental inventory (add/edit rental items with daily/weekly rates)
- Create rental agreements, track active rentals, and close them when returned

### 💰 Expenses
- Record operational expenses by category
- Feeds into the daily cash and monthly reports

### 📈 Reports
- **Daily cash report** — total cash in vs. out for any selected date
- **General reports** — period-wise revenue, purchase, and expense summaries

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Firebase Firestore |
| Auth | Firebase Auth + Google Sign-In |
| State | Riverpod 2.x |
| PDF | `pdf` + `printing` packages |
| Platforms | Android, iOS, Web |

---

## Project Structure

```
lib/
├── core/           # Theme, constants
├── models/         # Sale, Customer, Product, Rental, Expense, Purchase, …
├── providers/      # Riverpod providers (auth, data streams)
├── screens/
│   ├── dashboard/
│   ├── sales/
│   ├── customers/
│   ├── products/
│   ├── purchases/
│   ├── rentals/
│   ├── expenses/
│   ├── suppliers/
│   └── reports/
├── services/       # FirestoreService, AuthService, BillService
└── widgets/        # Shared UI components (StatCard, …)
```

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.9
- A Firebase project with Firestore and Authentication enabled

### Setup

1. Clone the repo and install dependencies:
   ```bash
   flutter pub get
   ```

2. Add your Firebase config files (not committed — keep these private):
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

3. Run on your target platform:
   ```bash
   flutter run                   # default device
   flutter run -d chrome         # web
   flutter build apk --release   # Android APK
   ```

---

## Security Note

`google-services.json` and `GoogleService-Info.plist` contain Firebase API keys and are listed in `.gitignore`. Never commit them to a public repository.

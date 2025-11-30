# EVSU Campus Pay (eCampusPay)

## 📱 Overview

**EVSU Campus Pay** is a comprehensive digital wallet and payment system designed specifically for Eastern Visayas State University (EVSU). This Flutter-based mobile application provides a secure, efficient, and modern payment solution for campus transactions, integrating RFID technology, Bluetooth connectivity, and cryptocurrency payments.

## 🎯 System Purpose

eCampusPay serves as the primary digital payment platform for EVSU, enabling:

- **Cashless Campus Transactions**: Students can pay for food, services, and other campus expenses using their digital wallet
- **RFID Tap-to-Pay**: Quick and convenient payments using RFID cards via ESP32 Bluetooth scanners
- **Service Management**: Vendors and service providers can manage their accounts and transactions
- **Administrative Control**: Comprehensive admin dashboard for system management and oversight
- **Loan System**: Built-in lending functionality for students with automated reminders
- **Multi-Platform Support**: Works on Android, iOS, and web platforms

## 🏗️ System Architecture

### Technology Stack

- **Frontend**: Flutter (Dart) - Cross-platform mobile development
- **Backend**: Supabase - Backend-as-a-Service with PostgreSQL database
- **Authentication**: Supabase Auth with custom encryption
- **Hardware Integration**: ESP32 microcontrollers with RFID readers
- **Bluetooth Communication**: BLE (Bluetooth Low Energy) for scanner connectivity
- **Cryptocurrency Integration**: Paytaca API for Bitcoin Cash payments
- **Security**: AES-256 encryption, SHA-256 password hashing, Row Level Security (RLS)

### Core Components

#### 1. **Mobile Application (Flutter)**

```
lib/
├── main.dart                    # Application entry point
├── login_page.dart             # Multi-role authentication
├── splash_page.dart            # App initialization
├── admin/                      # Admin dashboard modules
│   ├── admin_dashboard.dart    # Main admin interface
│   ├── dashboard_tab.dart      # System overview
│   ├── user_management_tab.dart # Student account management
│   ├── transactions_tab.dart   # Transaction monitoring
│   └── vendors_tab.dart        # Service account management
├── user/                       # Student user interface
│   ├── user_dashboard.dart     # Student main dashboard
│   ├── withdraw_screen.dart    # Balance withdrawal
│   └── security_privacy_screen.dart # Security settings
├── services_school/            # Service provider interface
│   ├── service_dashboard.dart  # Service account dashboard
│   ├── payment_screen.dart     # RFID payment processing
│   └── cashier_tab.dart        # Transaction management
├── services/                   # Core services
│   ├── supabase_service.dart   # Database operations
│   ├── encryption_service.dart # Data encryption/decryption
│   ├── session_service.dart    # User session management
│   ├── esp32_bluetooth_service.dart # Hardware communication
│   └── paytaca_invoice_service.dart # Cryptocurrency payments
└── config/                     # Configuration management
    └── supabase_config.dart    # Environment configuration
```

#### 2. **Hardware Components**

- **ESP32 Microcontrollers**: Handle RFID reading and Bluetooth communication
- **MFRC522 RFID Readers**: Process RFID card data
- **Bluetooth Low Energy (BLE)**: Wireless communication between scanners and mobile devices

#### 3. **Database Schema (Supabase/PostgreSQL)**

- **auth_students**: Student account information with encrypted data
- **service_accounts**: Vendor and service provider accounts
- **admin_accounts**: Administrative user accounts
- **scanner_devices**: RFID scanner device management
- **service_transactions**: Payment transaction records
- **loan_plans**: Student loan management
- **notifications**: System notification system

## 👥 User Roles & Permissions

### 1. **Students**

- **Access**: Personal dashboard, balance management, transaction history
- **Features**:
  - View account balance and transaction history
  - Top-up wallet via Paytaca (Bitcoin Cash)
  - Withdraw funds to external accounts
  - RFID card registration and management
  - Loan applications and payments
  - Receive system notifications

### 2. **Service Providers/Vendors**

- **Access**: Service dashboard, payment processing, transaction management
- **Features**:
  - Process RFID payments from students
  - Manage service items and pricing
  - View transaction history and analytics
  - Withdraw earnings to external accounts
  - Scanner device management

### 3. **Administrators**

- **Access**: Full system administration dashboard
- **Features**:
  - User management (students, service accounts)
  - Transaction monitoring and reporting
  - System configuration and API management
  - Scanner device assignment and management
  - Loan system administration
  - System maintenance and updates
  - Security and privacy controls

## 🔒 Security Features

### Data Protection

- **AES-256 Encryption**: All sensitive data (names, emails, RFID IDs) encrypted at rest
- **SHA-256 Password Hashing**: Secure password storage with salt
- **Row Level Security (RLS)**: Database-level access control
- **Environment Variables**: Sensitive configuration externalized
- **JWT Authentication**: Secure token-based authentication

### Access Control

- **Multi-Role Authentication**: Students, admins, and service accounts
- **Role-Based Permissions**: Granular access control based on user type
- **Session Management**: Secure session handling with automatic logout
- **API Security**: Protected endpoints with proper authentication

### Hardware Security

- **Encrypted RFID Communication**: RFID data encrypted during transmission
- **Bluetooth Security**: Secure BLE communication protocols
- **Device Authentication**: Scanner device verification and assignment

### Privacy Features

- **Data Minimization**: Only necessary data collected and stored
- **Secure Data Transmission**: All communications encrypted
- **Audit Logging**: Comprehensive transaction and access logging
- **GDPR Compliance**: Data protection and privacy controls

## 🔄 System Workflows

### 1. **User Registration & Authentication Flow**

```
1. App Launch → Splash Screen → Environment Initialization
2. Login Page → Multi-role Authentication (Student/Admin/Service)
3. Session Creation → Dashboard Navigation (Role-specific)
4. Username Remember Feature → Quick subsequent logins
```

### 2. **RFID Payment Flow**

```
1. Student taps RFID card on ESP32 scanner
2. Scanner reads card data → Encrypts and transmits via BLE
3. Flutter app receives data → Validates student account
4. Balance verification → Transaction processing
5. Database updates → Real-time balance synchronization
6. Receipt generation → Transaction logging
```

### 3. **Service Management Flow**

```
1. Service Provider login → Service dashboard access
2. Scanner assignment → RFID payment processing setup
3. Payment processing → Real-time transaction monitoring
4. Earnings management → Withdrawal to external accounts
5. Analytics and reporting → Business insights
```

### 4. **Administrative Management Flow**

```
1. Admin login → Administrative dashboard
2. User management → Account creation and maintenance
3. System monitoring → Transaction oversight
4. Configuration management → API and system settings
5. Maintenance operations → System updates and backups
```

## 🚀 Key Features

### For Students

- **Digital Wallet**: Secure balance management with top-up and withdrawal options
- **RFID Payments**: Quick tap-to-pay functionality for campus purchases
- **Transaction History**: Complete record of all financial activities
- **Loan System**: Apply for and manage student loans with automated reminders
- **Notifications**: Real-time updates on transactions and system events
- **Security Controls**: Privacy settings and security preferences

### For Service Providers

- **Payment Processing**: Real-time RFID payment acceptance
- **Inventory Management**: Track and manage service items
- **Earnings Tracking**: Monitor income and transaction analytics
- **Scanner Management**: Assign and manage RFID scanner devices
- **Withdrawal System**: Transfer earnings to external bank accounts

### For Administrators

- **System Oversight**: Complete administrative control and monitoring
- **User Management**: Create, modify, and manage all user accounts
- **Transaction Monitoring**: Real-time transaction tracking and reporting
- **System Configuration**: Manage API settings and system parameters
- **Security Management**: Monitor and control system security features
- **Maintenance Tools**: System updates, backups, and maintenance operations

## 🔧 Development & Deployment

### Prerequisites

- Flutter SDK (3.7.2+)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Supabase account and project
- ESP32 development boards with RFID readers

### Environment Setup

1. **Clone the repository**
2. **Install dependencies**: `flutter pub get`
3. **Configure environment variables** (see `ENVIRONMENT_SETUP.md`)
4. **Set up Supabase database** (see `migrations/README.md`)
5. **Configure ESP32 devices** (see `lib/esp/` for Arduino code)

### Database Migration

The system includes comprehensive database migration scripts:

- **Basic Setup**: Create essential tables and configurations
- **Security Setup**: Implement Row Level Security policies
- **Data Migration**: Import existing user data
- **System Configuration**: Set up API configurations and permissions

### Hardware Setup

1. **ESP32 Configuration**: Upload Arduino code to ESP32 devices
2. **RFID Reader Setup**: Connect MFRC522 readers to ESP32
3. **Scanner Registration**: Register devices in the admin system
4. **Service Assignment**: Assign scanners to specific service accounts

## 📊 System Monitoring & Analytics

### Real-time Monitoring

- **Transaction Tracking**: Live monitoring of all payment transactions
- **System Health**: Hardware and software status monitoring
- **User Activity**: Login patterns and usage analytics
- **Error Logging**: Comprehensive error tracking and reporting

### Reporting Features

- **Financial Reports**: Revenue, transaction volume, and balance analytics
- **User Reports**: Registration, activity, and engagement metrics
- **System Reports**: Performance, uptime, and maintenance reports
- **Security Reports**: Access logs and security event monitoring

## 🔄 Agile Development Process

### Development Methodology

The eCampusPay system follows **Agile development principles** with:

#### **Sprint Planning**

- **2-week sprints** with clear feature deliverables
- **User story mapping** for each role (Student, Service Provider, Admin)
- **Technical debt management** and refactoring cycles

#### **Continuous Integration**

- **Automated testing** for critical payment flows
- **Code review process** for security-sensitive components
- **Database migration testing** for schema changes
- **Hardware integration testing** for ESP32 and RFID components

#### **Iterative Development**

- **Feature-based development** with incremental releases
- **User feedback integration** from campus community
- **Performance optimization** based on real-world usage
- **Security updates** and vulnerability patching

#### **Quality Assurance**

- **Multi-platform testing** (Android, iOS, Web)
- **Hardware compatibility testing** with various ESP32 configurations
- **Security penetration testing** for payment systems
- **User acceptance testing** with actual campus users

### Version Control & Documentation

- **Git-based version control** with feature branching
- **Comprehensive documentation** for all system components
- **API documentation** for integration purposes
- **Hardware setup guides** for ESP32 and RFID configuration

## 🌟 Future Enhancements

### Planned Features

- **QR Code Payments**: Additional payment method integration
- **Offline Mode**: Limited functionality during network outages
- **Advanced Analytics**: Machine learning-based insights
- **Mobile Web Version**: Browser-based access for wider compatibility
- **Integration APIs**: Third-party service integration capabilities

### Scalability Considerations

- **Multi-campus Support**: Expansion to other educational institutions
- **Cloud Infrastructure**: Scalable backend architecture
- **Hardware Optimization**: Enhanced ESP32 firmware and capabilities
- **Performance Monitoring**: Advanced system performance tracking

## 📞 Support & Maintenance

### Technical Support

- **Documentation**: Comprehensive guides and troubleshooting
- **Community Support**: Campus IT support integration
- **Developer Resources**: API documentation and integration guides
- **Hardware Support**: ESP32 and RFID troubleshooting guides

### System Maintenance

- **Regular Updates**: Security patches and feature updates
- **Database Maintenance**: Performance optimization and cleanup
- **Hardware Maintenance**: Scanner device management and replacement
- **Backup & Recovery**: Data protection and disaster recovery procedures

---

## 📄 License

This project is developed for Eastern Visayas State University (EVSU) as part of a capstone project. All rights reserved.

## 👥 Development Team

**Capstone Project 2025** - EVSU Computer Science Department

---

_For technical support or feature requests, please contact the development team or refer to the comprehensive documentation included in this repository._

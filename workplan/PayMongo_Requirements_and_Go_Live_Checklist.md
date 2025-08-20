# PayMongo Requirements & Go-Live Checklist for AnnedFinds

## 📋 Overview
This document outlines all requirements needed to activate PayMongo payment processing for AnnedFinds e-commerce platform in production.

---

## 🏢 PayMongo Account Requirements

### 1. Business Registration Documents
**Required for all businesses:**
- [ ] **SEC Certificate of Registration** (for corporations)
- [ ] **DTI Business Name Registration** (for sole proprietorship)
- [ ] **BIR Certificate of Registration (Form 2303)**
- [ ] **Mayor's Permit / Business Permit**
- [ ] **Barangay Business Clearance**

### 2. Tax Documents
- [ ] **BIR Form 1901** (Application for Registration Information Update)
- [ ] **Latest ITR (Income Tax Return)** filed with BIR
- [ ] **TIN (Tax Identification Number)** certificate
- [ ] **VAT Registration Certificate** (if applicable)

### 3. Banking Information
**Primary Settlement Account:**
- [ ] **Bank Account Certificate** or **Bank Statement** (latest 3 months)
- [ ] **Authorized Bank Signatories List**
- [ ] Account must be a **business account** (not personal)
- [ ] Account must be in **PHP currency**

**Supported Banks for Settlement:**
- BDO, BPI, Metrobank, Security Bank, UnionBank, RCBC, EastWest, PNB, PSBank, China Bank, Land Bank, DBP

### 4. Identity Verification
**For Business Owner/Authorized Representative:**
- [ ] **Valid Government-issued ID** (Driver's License, Passport, UMID, SSS ID)
- [ ] **Proof of Address** (Utility bill, Bank statement - not older than 3 months)
- [ ] **Authorization Letter** (if representative is not the business owner)

### 5. Website/Business Verification
- [ ] **Fully functional website** with complete product catalog
- [ ] **Terms of Service** and **Privacy Policy** pages
- [ ] **Refund/Return Policy** clearly stated
- [ ] **Contact Information** (physical address, phone, email)
- [ ] **About Us** page with business information

---

## 💳 Payment Method Specific Requirements

### GCash Integration
- [ ] **No additional requirements** - automatically available once approved
- [ ] **Transaction limits:** ₱50,000 per transaction, ₱100,000 daily

### Credit/Debit Cards (Visa, Mastercard)
- [ ] **Enhanced KYC documents** may be required for higher limits
- [ ] **Processing fees:** 3.9% + ₱15 per transaction
- [ ] **3D Secure authentication** mandatory for all card transactions

### Online Banking (InstaPay/PESONet)
- [ ] **Bank partnership agreements** (handled by PayMongo)
- [ ] **Higher transaction limits** available: up to ₱500,000

### Cash on Delivery (COD)
- [ ] **Logistics partner integration** required
- [ ] **Manual settlement process** for COD orders
- [ ] **Additional verification** for high-value COD orders

---

## 🔐 Technical Requirements for Go-Live

### 1. SSL Certificate
- [ ] **Valid SSL certificate** installed on annedfinds.web.app
- [ ] **HTTPS enforcement** on all pages
- [ ] **Security headers** properly configured

### 2. Webhook Configuration
- [ ] **Webhook endpoint** configured at: `https://annedfinds.web.app/api/webhooks/paymongo`
- [ ] **Webhook signature verification** implemented
- [ ] **Failure handling and retry logic** in place

### 3. API Keys Configuration
**Test Environment (Current):**
- [x] Test Public Key: `pk_test_*` (already configured)
- [x] Test Secret Key: `sk_test_*` (already configured)

**Production Environment (Required):**
- [ ] **Production Public Key:** `pk_live_*` (to be provided after approval)
- [ ] **Production Secret Key:** `sk_live_*` (to be provided after approval)

### 4. Environment Variables Setup
```env
# Production Firebase Functions Configuration
PAYMONGO_PUBLIC_KEY=pk_live_[YOUR_LIVE_KEY]
PAYMONGO_SECRET_KEY=sk_live_[YOUR_LIVE_SECRET]
PAYMONGO_WEBHOOK_SECRET=[YOUR_WEBHOOK_SECRET]
FIREBASE_PROJECT_ID=annedfinds-web
```

---

## 💰 Financial Information Required

### 1. Transaction Volume Estimates
- [ ] **Expected monthly transaction volume** (₱ amount)
- [ ] **Expected number of transactions per month**
- [ ] **Average transaction value** (₱ amount)
- [ ] **Peak season projections** (holiday sales, etc.)

### 2. Settlement Preferences
- [ ] **Settlement frequency:** Daily, Weekly, or Monthly
- [ ] **Settlement bank account details:**
  - Account Name: ________________
  - Bank Name: ___________________
  - Account Number: ______________
  - Branch: _____________________

### 3. Fee Structure Acceptance
**PayMongo Standard Rates:**
- GCash: 2.9% + ₱15 per transaction
- Cards: 3.9% + ₱15 per transaction
- Online Banking: 1.5% + ₱15 per transaction
- COD: Varies by logistics partner

---

## 🚀 Go-Live Process Steps

### Phase 1: Account Application (1-2 weeks)
1. [ ] Submit all required documents to PayMongo
2. [ ] Complete KYC (Know Your Customer) verification
3. [ ] Wait for initial approval notification

### Phase 2: Technical Integration Review (3-5 days)
1. [ ] PayMongo reviews technical implementation
2. [ ] Security audit of webhook endpoints
3. [ ] Transaction flow testing in sandbox

### Phase 3: Production Activation (1-2 days)
1. [ ] Receive production API keys from PayMongo
2. [ ] Update Firebase Functions with live credentials
3. [ ] Deploy production configuration
4. [ ] Conduct live transaction testing (small amounts)

### Phase 4: Monitoring & Optimization (Ongoing)
1. [ ] Monitor transaction success rates
2. [ ] Track settlement timing
3. [ ] Optimize payment flow based on analytics

---

## 📞 Required Information for Developer

### 1. Business Details to Provide
```
Business Name: AnnedFinds
Business Type: E-commerce/Online Retail
Business Address: [YOUR COMPLETE ADDRESS]
Contact Person: [YOUR NAME]
Contact Email: [YOUR EMAIL]
Contact Phone: [YOUR PHONE NUMBER]
Website: https://annedfinds.web.app
```

### 2. Technical Contact Information
```
Technical Lead: [YOUR NAME OR DEVELOPER NAME]
Technical Email: [TECH SUPPORT EMAIL]
Emergency Contact: [24/7 CONTACT NUMBER]
```

### 3. Firebase Project Access
- [ ] **Firebase Console access** for production deployment
- [ ] **Cloud Functions deployment permissions**
- [ ] **Environment variables configuration access**

---

## ⚠️ Important Notes

### Compliance Requirements
- **PCI DSS Compliance:** PayMongo handles card data, but ensure your site follows security best practices
- **Data Privacy Act (DPA):** Implement proper data handling and privacy policies
- **BSP Regulations:** Ensure compliance with Bangko Sentral ng Pilipinas guidelines

### Timeline Expectations
- **Document Preparation:** 1-2 weeks
- **PayMongo Approval:** 2-4 weeks
- **Technical Go-Live:** 1 week
- **Total Timeline:** 4-7 weeks from document submission

### Common Rejection Reasons
- Incomplete business documentation
- Invalid/expired government registrations
- Insufficient website content or functionality
- High-risk business categories
- Incomplete tax compliance records

---

## 📋 Next Steps Checklist

**Immediate Actions Required:**
1. [ ] Gather all business registration documents
2. [ ] Prepare banking information and statements
3. [ ] Complete website compliance (Terms, Privacy Policy, etc.)
4. [ ] Provide business details and technical contact information
5. [ ] Submit PayMongo merchant application

**Technical Preparation:**
1. [ ] Verify SSL certificate installation
2. [ ] Test webhook endpoint functionality
3. [ ] Prepare production environment variables
4. [ ] Schedule go-live deployment window

**Post Go-Live:**
1. [ ] Monitor first transactions closely
2. [ ] Verify settlement process
3. [ ] Update customer support documentation
4. [ ] Implement transaction analytics tracking

---

## 📞 Support Contacts

- **PayMongo Support:** support@paymongo.com
- **Technical Issues:** developers@paymongo.com
- **Account Management:** merchants@paymongo.com
- **Emergency Support:** +63 (2) 8-651-7973

---

*Last Updated: August 15, 2025*
*Document Version: 1.0*
/// Official Uni Eats policy documents shown in the driver app's Legal section.
///
/// Content is curated for the driver audience from the source policy documents
/// (Legal/POLICIES/uni-eats-policies). Internal-only material (signature blocks,
/// revision tables, employee-only role duties) is trimmed; everything that
/// governs or informs a delivery partner is kept verbatim. Baked in as Dart
/// constants so policies are fully readable offline.
library;

enum PolicyBlockType { paragraph, bullet, subhead }

/// One renderable unit inside a policy section.
class PolicyBlock {
  final PolicyBlockType type;
  final String text;
  const PolicyBlock.p(this.text) : type = PolicyBlockType.paragraph;
  const PolicyBlock.b(this.text) : type = PolicyBlockType.bullet;
  const PolicyBlock.h(this.text) : type = PolicyBlockType.subhead;
}

class PolicySection {
  final String heading;
  final List<PolicyBlock> blocks;
  const PolicySection(this.heading, this.blocks);
}

class PolicyDoc {
  final String ref;
  final String title;
  final String effectiveDate;

  /// One-line "key takeaway" shown in the highlighted intro card.
  final String takeaway;
  final List<PolicySection> sections;

  const PolicyDoc({
    required this.ref,
    required this.title,
    required this.effectiveDate,
    required this.takeaway,
    required this.sections,
  });
}

/// All policies surfaced in the driver app, in display order.
const List<PolicyDoc> kDriverPolicies = [
  _driverSafety,
  _dataPrivacy,
  _acceptableUse,
  _foodSafety,
  _refundCancellation,
];

// =============================================================================
// UE-POL-DRV-001 — Driver Safety & Data Privacy
// =============================================================================
const _driverSafety = PolicyDoc(
  ref: 'UE-POL-DRV-001',
  title: 'Driver Safety & Data Privacy',
  effectiveDate: '22 June 2026',
  takeaway:
      'Every driver represents Uni Eats on campus and has access to customer '
      'personal data. Safe driving, professional conduct, and strict protection '
      'of customer privacy are non-negotiable conditions of being a Uni Eats '
      'delivery partner.',
  sections: [
    PolicySection('1. Purpose & Scope', [
      PolicyBlock.p(
          'This policy ensures that all Uni Eats delivery drivers operate safely, '
          'professionally, and in full compliance with Qatari traffic laws, labour '
          'laws, and data protection requirements. It protects drivers, customers, '
          'and the Uni Eats platform.'),
      PolicyBlock.p('It applies to:'),
      PolicyBlock.b('All student delivery partners registered on the Uni Eats platform.'),
      PolicyBlock.b(
          'All delivery activities performed on behalf of Uni Eats, including '
          'pickup, transport, and drop-off of orders.'),
      PolicyBlock.b(
          'All personal data you access or come into contact with during your work.'),
      PolicyBlock.b('All vehicles, bicycles, and equipment used for Uni Eats deliveries.'),
    ]),
    PolicySection('2. Your Commitments', [
      PolicyBlock.p('As a Uni Eats driver, you must:'),
      PolicyBlock.b(
          'Comply with all applicable Qatari traffic laws, including the Qatar '
          'Traffic Law (Law No. 19 of 2007), at all times.'),
      PolicyBlock.b(
          'Drive safely and responsibly. Reckless driving, speeding, or any '
          'traffic violation while on a delivery will result in immediate suspension.'),
      PolicyBlock.b(
          'Protect customer personal data and not use it for any purpose other '
          'than completing the delivery.'),
      PolicyBlock.b(
          'Treat every customer, vendor, and campus community member with respect '
          'and professionalism.'),
      PolicyBlock.b('Report any accident, incident, or safety concern to Uni Eats immediately.'),
    ]),
    PolicySection('3. Eligibility & Conduct', [
      PolicyBlock.h('Eligibility'),
      PolicyBlock.b('Must be a registered student at the university (UDST or partner institution).'),
      PolicyBlock.b('Must provide a valid student ID and university email for verification.'),
      PolicyBlock.b('Must hold a valid Qatar driving licence if using a motor vehicle.'),
      PolicyBlock.b(
          'Must not have a criminal record involving theft, fraud, violence, or '
          'sexual offences.'),
      PolicyBlock.b(
          'Must complete Uni Eats onboarding, including safety and privacy '
          'training, before accepting any delivery.'),
      PolicyBlock.h('Conduct'),
      PolicyBlock.b('Wear Uni Eats driver identification (badge, t-shirt, or armband) while on deliveries.'),
      PolicyBlock.b('Be courteous and professional with customers and restaurant vendors.'),
      PolicyBlock.b(
          'Do not use mobile phones while driving. Pull over safely before '
          'responding to calls, messages, or app notifications.'),
      PolicyBlock.b(
          'Do not consume alcohol, drugs, or any substance that could impair '
          'driving ability before or during deliveries.'),
      PolicyBlock.b('Do not carry passengers other than Uni Eats personnel during active deliveries.'),
      PolicyBlock.b('Do not accept or solicit tips beyond what is offered through the app.'),
      PolicyBlock.h('Working Hours'),
      PolicyBlock.b('Do not work more than 6 consecutive hours without a 30-minute break.'),
      PolicyBlock.b('Do not work more than 48 hours in a calendar week (Qatar Labour Law).'),
      PolicyBlock.b('Take at least one full day off per week.'),
      PolicyBlock.b('Drivers under 18 must not work between 8:00 PM and 6:00 AM.'),
    ]),
    PolicySection('4. Vehicle & Equipment Safety', [
      PolicyBlock.h('Motor Vehicles'),
      PolicyBlock.b('The vehicle must be roadworthy and pass a basic safety inspection before onboarding.'),
      PolicyBlock.b('Valid vehicle registration and insurance are required and must be provided to Uni Eats.'),
      PolicyBlock.b('Food must be carried in the passenger cabin or a clean, enclosed storage area — not in the boot with non-food items.'),
      PolicyBlock.h('Bicycles'),
      PolicyBlock.b('The bicycle must have functioning brakes, lights, and tyres.'),
      PolicyBlock.b('A helmet must be worn at all times while riding.'),
      PolicyBlock.b('Reflective clothing or a high-visibility vest is recommended, especially at night.'),
      PolicyBlock.h('Delivery Equipment'),
      PolicyBlock.b('Use the insulated delivery bag provided or approved by Uni Eats for all deliveries.'),
      PolicyBlock.b('Clean and sanitise delivery bags after each shift.'),
      PolicyBlock.b('Carry a phone with the Driver App installed and enough battery for your shift. A portable charger is recommended.'),
    ]),
    PolicySection('5. Data Privacy & Confidentiality', [
      PolicyBlock.p(
          'You have access to customer personal data to perform deliveries — '
          'name, phone number, delivery address, and order details. This data '
          'must be protected.'),
      PolicyBlock.h('Privacy Rules'),
      PolicyBlock.b('Customer data may only be used for the sole purpose of completing the delivery.'),
      PolicyBlock.b('Do not save, store, screenshot, photograph, record, or share customer personal data for any reason.'),
      PolicyBlock.b('Do not contact customers outside the Uni Eats app for anything unrelated to the current delivery.'),
      PolicyBlock.b('Do not visit, return to, or share a customer delivery address after the delivery is complete.'),
      PolicyBlock.b('Do not post about customers, orders, or delivery experiences on social media or any public platform.'),
      PolicyBlock.b('Do not share your Driver App login credentials with anyone.'),
      PolicyBlock.h('Violations'),
      PolicyBlock.p(
          'Any unauthorised use, disclosure, or retention of customer personal '
          'data is a serious violation of this policy and of Qatar PDPPL Law '
          '13/2016. Drivers who violate customer privacy will be immediately and '
          'permanently removed from the platform and may be referred to university '
          'authorities or law enforcement.'),
    ]),
    PolicySection('6. Incident Reporting', [
      PolicyBlock.p('Report the following to Uni Eats operations immediately:'),
      PolicyBlock.b('Any accident involving injury, vehicle damage, or property damage while on a delivery.'),
      PolicyBlock.b('Any interaction with law enforcement or traffic authorities related to a delivery.'),
      PolicyBlock.b('Any suspected or actual loss, theft, or unauthorised access to the Driver App or your account.'),
      PolicyBlock.b('Any complaint from a customer or vendor about your conduct, delivery quality, or food safety.'),
      PolicyBlock.b('Any personal data incident, including accidental disclosure of customer information or loss of a device containing customer data.'),
      PolicyBlock.p(
          'Report through the Driver App or by contacting Uni Eats operations '
          'directly. Minor incidents must be reported within 24 hours; serious '
          'incidents within 2 hours.'),
    ]),
  ],
);

// =============================================================================
// UE-POL-PRIV-001 — Data Protection & Privacy
// =============================================================================
const _dataPrivacy = PolicyDoc(
  ref: 'UE-POL-PRIV-001',
  title: 'Data Protection & Privacy',
  effectiveDate: '22 June 2026',
  takeaway:
      'Data protection is a legal requirement, not a choice. Every individual '
      'who handles Uni Eats data — including your own — has a responsibility to '
      'protect it, under Qatar PDPPL Law 13/2016.',
  sections: [
    PolicySection('1. Purpose & Scope', [
      PolicyBlock.p(
          'This policy governs how Uni Eats collects, uses, stores, shares, and '
          'destroys personal data, in compliance with the Qatar Personal Data '
          'Privacy Protection Law (Law No. 13 of 2016) and applicable international '
          'data protection laws.'),
      PolicyBlock.p('It applies to the personal data of everyone who uses Uni Eats, including student delivery partners who use the Driver App.'),
    ]),
    PolicySection('2. Our Data Protection Principles', [
      PolicyBlock.b('Lawfulness, fairness, and transparency: we process data lawfully and tell you how it is used.'),
      PolicyBlock.b('Purpose limitation: we collect data only for specified, legitimate purposes.'),
      PolicyBlock.b('Data minimisation: we collect only what is necessary.'),
      PolicyBlock.b('Accuracy: we keep data accurate and up to date; inaccurate data is corrected or erased without delay.'),
      PolicyBlock.b('Storage limitation: we retain data only as long as necessary.'),
      PolicyBlock.b('Integrity and confidentiality: we protect data against unauthorised processing, loss, or damage.'),
      PolicyBlock.b('Accountability: we keep records of processing and can demonstrate compliance.'),
    ]),
    PolicySection('3. Your Responsibilities', [
      PolicyBlock.p('Every individual with access to personal data — including delivery partners — must:'),
      PolicyBlock.b('Process personal data only as authorised and instructed.'),
      PolicyBlock.b('Report any suspected data breach, unauthorised access, or loss of personal data immediately.'),
      PolicyBlock.b('Not download, screenshot, copy, or transfer personal data to personal devices or unauthorised systems.'),
      PolicyBlock.b('Complete data protection training within 7 days of onboarding and annually thereafter.'),
    ]),
    PolicySection('4. Your Data Rights', [
      PolicyBlock.p('Under Qatar PDPPL Law 13/2016 you have the following rights over your own personal data:'),
      PolicyBlock.h('Access'),
      PolicyBlock.p('Request a copy of your data by emailing unieats.qa@gmail.com with the subject "Data Access Request". Responded to within 30 days.'),
      PolicyBlock.h('Rectification'),
      PolicyBlock.p('Correct basic data (name, phone, address) via in-app profile edit. Email the DPO for verification data such as your university ID.'),
      PolicyBlock.h('Erasure'),
      PolicyBlock.p('Request deletion of your data within 30 days, unless retention is required by law (e.g. payment records). Data that cannot be erased is anonymised.'),
      PolicyBlock.h('Restrict Processing'),
      PolicyBlock.p('Request that processing be paused while a dispute about accuracy or lawfulness is resolved.'),
      PolicyBlock.h('Data Portability'),
      PolicyBlock.p('Receive the data you provided (identity, contact, order history) in JSON or CSV format.'),
      PolicyBlock.h('Object & Withdraw Consent'),
      PolicyBlock.p('Opt out of marketing at any time via app settings, and withdraw consent for processing based on consent.'),
    ]),
    PolicySection('5. How We Secure Your Data', [
      PolicyBlock.b('In transit: TLS 1.3 for all API communications, app traffic, and admin access.'),
      PolicyBlock.b('At rest: AES-256 encryption for databases containing personal data.'),
      PolicyBlock.b('Passwords: hashed using bcrypt or Argon2id with salting.'),
      PolicyBlock.b('Access control: role-based access and least privilege — you only access data necessary for your role.'),
      PolicyBlock.b('Logging: all access to personal data is logged, and anomalous patterns trigger alerts.'),
    ]),
    PolicySection('6. Data Breaches', [
      PolicyBlock.p(
          'Personal data breaches are reported to the Qatar MCIT / CDPD within 72 '
          'hours of discovery. If a breach is likely to put your rights at high '
          'risk, you will be notified without undue delay by email and in-app '
          'notification.'),
      PolicyBlock.p('To raise a data protection question or request, contact unieats.qa@gmail.com.'),
    ]),
  ],
);

// =============================================================================
// UE-POL-AUP-001 — Acceptable Use
// =============================================================================
const _acceptableUse = PolicyDoc(
  ref: 'UE-POL-AUP-001',
  title: 'Acceptable Use Policy',
  effectiveDate: '22 June 2026',
  takeaway:
      'Every user of Uni Eats systems is responsible for using them responsibly. '
      'Misuse — accidental or intentional — can lead to data breaches, legal '
      'liability, and removal from the platform.',
  sections: [
    PolicySection('1. Purpose & Scope', [
      PolicyBlock.p(
          'This policy establishes clear rules for the responsible and secure use '
          'of Uni Eats systems, devices, networks, and data. It applies to '
          'everyone who accesses any Uni Eats system, including student delivery '
          'partners using the Driver App.'),
      PolicyBlock.p(
          'It supports compliance with the Qatar Cybercrime Law (Law No. 14 of '
          '2014) and the Personal Data Privacy Protection Law (Law No. 13 of 2016).'),
    ]),
    PolicySection('2. Your Responsibilities', [
      PolicyBlock.b('Use Uni Eats systems only for lawful purposes and in compliance with Qatari law.'),
      PolicyBlock.b('Protect the confidentiality, integrity, and availability of Uni Eats data and systems.'),
      PolicyBlock.b('Use strong passwords and keep your credentials confidential.'),
      PolicyBlock.b('Report suspected security incidents, policy violations, or vulnerabilities immediately.'),
      PolicyBlock.b('Log out when not in active use and lock your device when unattended.'),
      PolicyBlock.b('Respect the privacy of Uni Eats users, partners, and employees.'),
    ]),
    PolicySection('3. Prohibited Uses', [
      PolicyBlock.h('Unauthorised Access'),
      PolicyBlock.b('Accessing any Uni Eats system, account, or data without authorisation.'),
      PolicyBlock.b('Sharing account credentials, passwords, or tokens with anyone.'),
      PolicyBlock.b('Using another person\'s account, or circumventing security controls.'),
      PolicyBlock.h('Data Misuse'),
      PolicyBlock.b('Copying, modifying, or deleting data without authorisation.'),
      PolicyBlock.b('Transferring Uni Eats data to personal devices or unapproved storage.'),
      PolicyBlock.b('Sharing customer personal data (names, phone numbers, addresses, student IDs) with unauthorised parties.'),
      PolicyBlock.b('Screenshotting, photographing, or recording customer information, order details, or delivery addresses.'),
      PolicyBlock.h('System Abuse'),
      PolicyBlock.b('Installing unauthorised software or connecting unauthorised hardware.'),
      PolicyBlock.b('Introducing malware or malicious code.'),
      PolicyBlock.b('Conducting security testing without explicit written authorisation.'),
      PolicyBlock.h('Conduct & Financial Integrity'),
      PolicyBlock.b('Harassing, threatening, or bullying other users, employees, customers, or partners.'),
      PolicyBlock.b('Misrepresenting your identity, role, or affiliation with Uni Eats.'),
      PolicyBlock.b('Tampering with payment amounts, fees, commissions, or financial records.'),
      PolicyBlock.b('Exploiting pricing errors, discount codes, or promotions for personal gain.'),
    ]),
    PolicySection('4. System & Network Security', [
      PolicyBlock.b('Use strong, unique passwords of at least 12 characters for all Uni Eats accounts.'),
      PolicyBlock.b('Enable multi-factor authentication (MFA) on all accounts that support it.'),
      PolicyBlock.b('Lock your device screen when leaving it unattended, even briefly.'),
      PolicyBlock.b('Report lost or stolen devices immediately.'),
      PolicyBlock.b('Keep the Driver App updated to the latest version.'),
      PolicyBlock.b('Do not use public or unsecured Wi-Fi when accessing systems containing customer data.'),
      PolicyBlock.b('Do not share your Driver App login or let others use your account to make deliveries.'),
    ]),
    PolicySection('5. Monitoring & Reporting', [
      PolicyBlock.p(
          'Uni Eats may monitor, record, and review use of its systems to ensure '
          'compliance — including access logs and audits of data access patterns. '
          'You should not expect privacy when using Uni Eats-owned devices or systems.'),
      PolicyBlock.p(
          'Report suspected violations to unieats.qa@gmail.com. Reports may be made '
          'anonymously, are handled confidentially, and no retaliation will be '
          'taken against anyone who reports in good faith.'),
    ]),
  ],
);

// =============================================================================
// UE-POL-FOOD-001 — Food Safety & Handling
// =============================================================================
const _foodSafety = PolicyDoc(
  ref: 'UE-POL-FOOD-001',
  title: 'Food Safety & Handling',
  effectiveDate: '22 June 2026',
  takeaway:
      'Food safety is non-negotiable. Every driver must handle food in a way '
      'that preserves its safety and quality during transport, from pickup to '
      'doorstep.',
  sections: [
    PolicySection('1. Purpose & Scope', [
      PolicyBlock.p(
          'This policy sets the minimum food safety standards that every vendor '
          'and driver on the Uni Eats platform must follow. It supports compliance '
          'with the Qatar Food Safety Law (Law No. 8 of 1990), the Ministry of '
          'Public Health (MOPH), and the Municipality of Doha (Baladiya).'),
    ]),
    PolicySection('2. Your Responsibilities as a Driver', [
      PolicyBlock.b('Transport food in clean, insulated delivery bags that maintain appropriate temperature.'),
      PolicyBlock.b('Never open, tamper with, or consume any part of a customer order during transport.'),
      PolicyBlock.b('Deliver orders promptly and never leave orders unattended in unsafe conditions.'),
      PolicyBlock.b('Report any spillage, damage, or suspected contamination of an order to Uni Eats immediately.'),
      PolicyBlock.b('Maintain basic personal hygiene and keep your delivery equipment clean.'),
    ]),
    PolicySection('3. Transport & Delivery Standards', [
      PolicyBlock.h('Transport'),
      PolicyBlock.b('Carry hot food in hot bags and cold food in cold bags.'),
      PolicyBlock.b('Clean and sanitise delivery bags after each shift.'),
      PolicyBlock.b('Separate multiple orders in a single trip to prevent cross-contamination and flavour transfer.'),
      PolicyBlock.b('Never place food bags on the ground, in a vehicle trunk with non-food items, or in direct sunlight.'),
      PolicyBlock.b('Keep your delivery vehicle clean if using a personal vehicle.'),
      PolicyBlock.h('Delivery Times'),
      PolicyBlock.b('Aim to deliver within 30 minutes of pickup to minimise food safety risk.'),
      PolicyBlock.b('If a delivery cannot be completed within 45 minutes of pickup, notify Uni Eats operations.'),
      PolicyBlock.b('Significant delays (over 60 minutes) require the order to be evaluated for food safety before delivery; if safety cannot be guaranteed, the order must be discarded and replaced.'),
    ]),
    PolicySection('4. Incident Reporting', [
      PolicyBlock.p('Report any food safety incident to Uni Eats operations within 2 hours of discovery. This includes:'),
      PolicyBlock.b('A packaging failure resulting in spillage, leakage, or contamination.'),
      PolicyBlock.b('Discovery of contaminated, spoiled, or incorrectly prepared food.'),
      PolicyBlock.b('A temperature control failure during transport.'),
      PolicyBlock.b('Any customer complaint alleging a food quality or safety problem.'),
    ]),
  ],
);

// =============================================================================
// UE-POL-REF-001 — Refund & Cancellation
// =============================================================================
const _refundCancellation = PolicyDoc(
  ref: 'UE-POL-REF-001',
  title: 'Refund & Cancellation',
  effectiveDate: '22 June 2026',
  takeaway:
      'Every refund and cancellation is handled promptly, transparently, and '
      'fairly. Drivers are entitled to fair compensation for completed work.',
  sections: [
    PolicySection('1. Purpose & Scope', [
      PolicyBlock.p(
          'This policy sets clear rules for when and how orders can be cancelled '
          'or refunded, balancing the interests of customers, vendors, and drivers '
          'while complying with the Qatar Consumer Protection Law (Law No. 8 of 2008).'),
    ]),
    PolicySection('2. Order Cancellations', [
      PolicyBlock.h('Customer-Initiated'),
      PolicyBlock.b('A customer may cancel free of charge any time before the restaurant accepts the order.'),
      PolicyBlock.b('Once the restaurant accepts, the customer may only cancel if the restaurant agrees.'),
      PolicyBlock.b('After a driver picks up the order, cancellation is not possible — the customer must refuse delivery and contact support for a refund.'),
      PolicyBlock.h('Restaurant-Initiated'),
      PolicyBlock.b('A restaurant may cancel if items are unavailable or it cannot fulfil the order.'),
      PolicyBlock.b('The customer is notified immediately and a full refund is processed automatically if already paid.'),
      PolicyBlock.h('Driver-Initiated'),
      PolicyBlock.b('You may cancel a delivery assignment if you cannot complete it due to vehicle issues, a personal emergency, or a safety concern.'),
      PolicyBlock.b('The order is reassigned to another available driver and the customer is notified of the delay.'),
      PolicyBlock.h('Force Majeure'),
      PolicyBlock.b('During a campus closure, severe weather, or public health emergency, in-progress orders may be cancelled with full refunds to customers.'),
      PolicyBlock.b('Vendors and drivers are compensated for completed work up to the point of cancellation, at Uni Eats discretion.'),
    ]),
    PolicySection('3. Driver Payment Disputes', [
      PolicyBlock.b('You may dispute a cancellation that affected your earnings if the cancellation was not your fault.'),
      PolicyBlock.b('Uni Eats reviews the delivery logs and GPS data to determine whether you completed your portion of the delivery.'),
      PolicyBlock.b('Drivers are not compensated for orders cancelled before they accepted the delivery assignment.'),
    ]),
    PolicySection('4. Refund Processing', [
      PolicyBlock.p('For awareness, approved customer refunds are processed within 5–10 business days of approval:'),
      PolicyBlock.b('Card payments (noqoody): credited to the original card; timing depends on the issuing bank.'),
      PolicyBlock.b('QPay: refunded to the original account within 3 business days.'),
      PolicyBlock.b('Wallet payments: credited to the in-app wallet within 24 hours.'),
      PolicyBlock.b('Cash on delivery: the customer is not charged, so no refund is needed.'),
    ]),
  ],
);

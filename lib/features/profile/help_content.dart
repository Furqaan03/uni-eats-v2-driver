/// Static content for the Help & Support screen — campus emergency procedures
/// and driver FAQ. Baked in as constants so it is fully available offline,
/// which matters most exactly when it's needed (an emergency, or no signal).
library;

import 'package:flutter/material.dart';

// =============================================================================
// Contacts
// =============================================================================

/// UDST Campus Security — the single on-campus number for fire, medical, first
/// aid, and security emergencies (source: UDST official emergency info).
const String kCampusSecurityDisplay = '4495 2999';
const String kCampusSecurityTel = '+97444952999';

/// Qatar national emergency line — life-threatening situations off campus.
const String kNationalEmergency = '999';

/// Uni Eats operations — app, orders, payouts, and incident reports.
const String kOpsEmail = 'support@unieats.qa';
const String kOpsPhoneDisplay = '+974 6684 4777';
const String kOpsTel = '+97466844777';
const String kOpsWhatsApp = '97466844777';

// =============================================================================
// Campus emergency procedures (UDST)
// =============================================================================

class EmergencyProcedure {
  final String title;
  final IconData icon;
  final List<String> steps;

  /// Optional availability note (e.g. first-aid responder hours).
  final String? note;
  const EmergencyProcedure({
    required this.title,
    required this.icon,
    required this.steps,
    this.note,
  });
}

const List<EmergencyProcedure> kEmergencyProcedures = [
  EmergencyProcedure(
    title: 'Fire',
    icon: Icons.local_fire_department_outlined,
    steps: [
      'Activate the nearest fire alarm.',
      'Evacuate the building and go immediately to the Assembly Point. Do not leave the campus.',
      'Call Campus Security at $kCampusSecurityDisplay.',
      'Do not re-enter the building until the Campus Fire Marshal gives the "all-clear" signal.',
    ],
  ),
  EmergencyProcedure(
    title: 'First Aid',
    icon: Icons.medical_services_outlined,
    steps: [
      'Report all first-aid incidents promptly — call the nearest security staff.',
      'First-aid kits are readily available in every building.',
      'Automated External Defibrillators (AEDs) are in most buildings.',
    ],
    note: 'First-aid responders are available 7:30 AM – 3:00 PM (Sun–Thurs).',
  ),
  EmergencyProcedure(
    title: 'Medical Emergency',
    icon: Icons.emergency_outlined,
    steps: [
      'Call $kCampusSecurityDisplay. The operator will gather essential information and call for the correct assistance.',
      'If the individual is unconscious or not breathing, ask the operator to have a defibrillator (AED) and first-aid kit brought to the scene.',
      'The operator can call an ambulance and the campus nurse (or a back-up first-aider) to assist.',
      'Only trained first-aiders should provide assistance. Ask security staff or nearby people to help as needed.',
      'Hand over first-aid responsibility to the ambulance crew or nurse on their arrival.',
      'Fill out the required first-aid report.',
    ],
  ),
];

// =============================================================================
// Driver FAQ
// =============================================================================

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

const List<FaqItem> kDriverFaq = [
  FaqItem(
    'Why am I not receiving new orders?',
    'First, make sure you are set to Online on the Home screen — you only receive '
        'orders while online. Orders are also capacity-limited: you can hold up to '
        '3 active deliveries at once, so finish or hand off a delivery to free a '
        'slot. If your account is suspended, you will not receive any orders until '
        'it is reinstated — check the banner on your profile.',
  ),
  FaqItem(
    'How is my payout calculated?',
    'You earn a flat QAR 5 for every completed delivery, regardless of the order '
        'size or distance. Cancelled or abandoned deliveries do not pay out. Your '
        'earnings are summarised on the Earnings screen and each completed trip is '
        'listed in History.',
  ),
  FaqItem(
    'When and how do I get paid?',
    'Payouts are sent to the bank account on file. Add or update your card name, '
        'IBAN, and mobile number under Profile → Payout details. Make sure these are '
        'correct and complete, or payouts may be delayed.',
  ),
  FaqItem(
    'What should I do if I can\'t reach the customer at drop-off?',
    'On the active delivery screen, use "Customer unreachable" to flag it. This '
        'notifies the customer and Uni Eats without you having to abandon a delivery '
        'you have already completed the run for. Wait a reasonable time for a '
        'response before contacting operations.',
  ),
  FaqItem(
    'How do I report an accident or incident during a delivery?',
    'For a physical emergency on campus, call UDST Campus Security ($kCampusSecurityDisplay) '
        'first. Once safe, report the incident to Uni Eats from the active delivery '
        'screen ("Report an incident") or by contacting operations. Accidents, '
        'injuries, and safety issues must be reported within 2 hours.',
  ),
  FaqItem(
    'What happens if I cancel or abandon a delivery?',
    'Before pickup, you can give up a delivery — it returns to the available-orders '
        'pool for another driver to claim, and the customer is notified of the delay. '
        'Abandoned deliveries do not pay out and are recorded in your History. After '
        'pickup, you cannot abandon an order; contact operations if there is a problem.',
  ),
  FaqItem(
    'How do I get my documents verified?',
    'Upload your QID, Student ID, Class Schedule, and CV under Profile → Documents. '
        'Each document is reviewed and marked Pending, Verified, or Rejected. If a '
        'document is rejected, upload a clearer copy to try again. You must be '
        'verified before you can take deliveries.',
  ),
  FaqItem(
    'Why was my account suspended?',
    'Accounts may be suspended for policy violations — unsafe driving, mishandling '
        'customer data, or repeated complaints (see the Driver Safety & Data Privacy '
        'policy). Suspension takes effect immediately. Contact Uni Eats operations to '
        'understand the reason and the steps to reinstate your account.',
  ),
  FaqItem(
    'How do I update my profile photo or details?',
    'Tap your photo on the Profile screen to change it, and use the edit options to '
        'update your name, phone, or campus. Verification documents (QID, Student ID) '
        'are changed through the Documents section.',
  ),
];

/// 用户协议 / 隐私政策静态文案（英文出海版，结构对齐小程序 agreement / privacy 页）。
///
/// 更新日期同步展示在页面顶部。
library;

/// 联系邮箱（与小程序 src/lib/constants.js CONTACT_EMAIL 一致）。
const String contactEmail = 'fishspotradar@163.com';

/// 协议/政策更新日期。
const String legalUpdatedAt = '2026-10-04';

/// 单个章节：标题 + 段落。
class LegalSection {
  const LegalSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

/// 用户协议正文。
const List<LegalSection> agreementSections = <LegalSection>[
  LegalSection(
    title: '1. Acceptance of These Terms',
    paragraphs: [
      'Welcome to VoltLedger (the "Service"). These Terms constitute the agreement between you and the Service regarding your use of the Service.',
      'Before using the Service, you should read and understand these Terms in their entirety. By downloading, opening, or using the Service in any way, you acknowledge that you have read and agree to be bound by all of these Terms.',
      'If you do not agree with any part of these Terms, please stop using the Service.',
    ],
  ),
  LegalSection(
    title: '2. About the Service',
    paragraphs: [
      'VoltLedger is a practical companion app for electric vehicle owners. It currently provides charging record management, charging statistics, cost and time-of-use electricity pricing calculators, and fuel-versus-EV cost comparison tools.',
      'All calculation results produced by the Service (including, without limitation, cost estimates, cost comparisons, and charging cost statistics) are derived from the data you enter and default parameters. They are provided for reference only and do not constitute purchasing advice or a basis for any decision.',
      'The Service may be updated from time to time with new features, interface changes, or adjusted content. The features actually provided in the app shall prevail.',
    ],
  ),
  LegalSection(
    title: '3. No Account Required',
    paragraphs: [
      'VoltLedger does not require registration, sign-in, or an account. There is no login flow, and the Service does not collect account credentials.',
      'Your nickname, avatar, and preferences are optional profile details stored only on your device, and you may clear or change them at any time.',
      'Because no account exists, you remain in full control of your data at all times, as described in the Privacy Policy.',
    ],
  ),
  LegalSection(
    title: '4. Acceptable Use',
    paragraphs: [
      'When using the Service, you agree to comply with all applicable laws and regulations, and not to use the Service for any unlawful purpose.',
      'You may not disrupt the normal operation of the Service through technical means or attempt to access data belonging to other users.',
      'You are solely responsible for the content you enter. Do not enter content that violates laws and regulations or infringes the rights of others.',
    ],
  ),
  LegalSection(
    title: '5. Data Storage and Deletion',
    paragraphs: [
      'Your charging records, expenses, vehicle profiles, and other data are stored locally on your device. The Service does not operate a server copy of your data, except for the third-party service calls explicitly described in the Privacy Policy.',
      'You may delete any record you have entered within the app at any time. Deletions are permanent and cannot be undone, so please confirm before deleting.',
      'Backup files you export contain your own data. Once exported, they are under your control, and you are responsible for storing them safely.',
    ],
  ),
  LegalSection(
    title: '6. Disclaimer of Warranty',
    paragraphs: [
      'All calculations and statistics provided by the Service are for reference only. They may differ from actual results due to electricity pricing policies, parameter settings, or data entry errors. Any decision you make based on them is your own responsibility.',
      'The Service is provided on an "as is" and "as available" basis, without warranties of any kind. The Service does not guarantee uninterrupted operation and is not liable for losses caused by suspension or interruption due to maintenance, upgrades, or other causes beyond its reasonable control.',
      'The Service is not responsible for recovering data lost as a result of your own deletion of records, clearing of app data, or uninstallation of the app.',
    ],
  ),
  LegalSection(
    title: '7. Intellectual Property',
    paragraphs: [
      'The interface design, code, icons, and related content of the Service are the intellectual property of the operator of the Service.',
      'No one may copy, republish, or use them for other commercial purposes without permission.',
    ],
  ),
  LegalSection(
    title: '8. Changes to These Terms and Termination',
    paragraphs: [
      'The Service may revise these Terms from time to time to reflect feature adjustments or legal requirements. Revised Terms will be published on this page with an updated date.',
      'If you continue to use the Service after the Terms are revised, you are deemed to have accepted the revised Terms.',
      'If you breach these Terms, the Service reserves the right to suspend or terminate the provision of the Service to you.',
    ],
  ),
  LegalSection(
    title: '9. Contact Us',
    paragraphs: [
      'If you have any questions or suggestions about these Terms, you may contact us by email at $contactEmail.',
    ],
  ),
];

/// 隐私政策正文。
const List<LegalSection> privacySections = <LegalSection>[
  LegalSection(
    title: '1. Introduction',
    paragraphs: [
      'VoltLedger (the "Service") takes your privacy seriously. This Policy explains what information the Service handles, how it is used and stored, and the rights you have in connection with it.',
      'Please read this Policy carefully before using the Service. By using the Service, you agree to the information practices described in this Policy.',
    ],
  ),
  LegalSection(
    title: '2. Information We Handle',
    paragraphs: [
      'Data you enter: To use features such as charging records and cost statistics, you may voluntarily enter data such as charging amounts, energy, dates, and vehicle details. This data is stored locally on your device and is not uploaded to any server.',
      'Optional profile information: If you choose to set a nickname or avatar, it is stored only on your device for display purposes. No account or sign-in is required.',
      'Device and runtime information: The Service may use basic device characteristics (such as screen size and operating system version) solely to lay out its interface correctly.',
      'The Service does not collect sensitive identity information that is unrelated to providing the Service, such as government ID numbers or bank card numbers.',
    ],
  ),
  LegalSection(
    title: '3. How Information Is Used',
    paragraphs: [
      'Providing core features: Saving and displaying your charging records, computing statistics (cumulative cost, cost per kWh, and so on), and running tools such as fuel-versus-EV comparison and time-of-use pricing calculations. These computations run on your device using the data you enter.',
      'Third-party feature calls: Some features rely on external services, and data is sent only when you actively trigger the corresponding feature. When you search for nearby charging stations, your current coordinates are sent over an encrypted connection (HTTPS) to OpenStreetMap (the Overpass API, https://www.openstreetmap.org) to query charging station locations; that query is subject to the OpenStreetMap Foundation privacy policy (https://wiki.osmfoundation.org/wiki/Privacy_Policy). If you use receipt scanning, a single compressed image of the receipt is sent over an encrypted connection (HTTPS) to Zhipu AI (https://open.bigmodel.cn), a third-party optical character recognition service, to extract the text, and is handled under that provider\'s own privacy policy. Converting coordinates into place names is performed on your device by the system location service. If you deny the relevant permission, nothing is sent.',
      'Receipt images may contain personal details (such as your name or phone number). Only scan receipts you are comfortable sending to the recognition service for processing.',
      'No analytics or tracking: The app contains no third-party analytics, advertising, or tracking SDKs, and we do not collect usage data. We do not track you across other apps or websites, and we do not sell or share your information for advertising or tracking purposes.',
    ],
  ),
  LegalSection(
    title: '4. Information Storage',
    paragraphs: [
      'Local storage: All of your data — charging records, expenses, vehicle profiles, memos, and preferences — is stored locally on your device using the app\'s local storage. The Service operates no user-facing server database.',
      'Backups: Backup files you export contain your own data and are saved wherever you choose to save them. The Service cannot access files after you share or store them.',
      'Storage duration: Because your data resides on your device, it is retained for as long as you keep the app and its data. Removing the app removes the data stored on your device.',
    ],
  ),
  LegalSection(
    title: '5. Sharing and Disclosure',
    paragraphs: [
      'The Service does not sell your personal information to any third party.',
      'Except in the following situations, we do not share your personal information: with your explicit consent; where required by law or by a competent authority; or where necessary to protect the lawful rights and interests of users or the public.',
    ],
  ),
  LegalSection(
    title: '6. Third-Party Services and Permissions',
    paragraphs: [
      'Some features rely on third-party services, including map and location services, receipt recognition, and product search and affiliate links. When you use these features, the data described in Section 3 is transmitted to the corresponding service provider and is subject to that provider\'s own privacy policy.',
      'If a feature requires a device permission (such as location, camera, or photo library), the Service explains the purpose at the time of use. You may grant or revoke these permissions at any time in your device settings; related features will degrade gracefully when a permission is denied.',
    ],
  ),
  LegalSection(
    title: '7. Your Rights',
    paragraphs: [
      'Access and correction: You can view and modify the charging records and other information you have entered at any time within the app.',
      'Deletion: You may delete specific records in the app at any time. Deletion is permanent and cannot be undone.',
      'Clearing local data: You can clear all locally stored data at any time by deleting the app\'s data or uninstalling the app.',
      'No account deletion is needed because the Service does not create accounts or store your data on any server.',
    ],
  ),
  LegalSection(
    title: '8. Children',
    paragraphs: [
      'The Service is intended for adult users. If you are a minor, please use the Service under the guidance of a parent or guardian and obtain their consent before entering any information.',
    ],
  ),
  LegalSection(
    title: '9. Updates to This Policy',
    paragraphs: [
      'This Policy may be updated from time to time. Updates will be published on this page with an updated date. If you continue to use the Service after an update, you are deemed to accept the updated Policy.',
    ],
  ),
  LegalSection(
    title: '10. Contact Us',
    paragraphs: [
      'If you have any questions, comments, or requests regarding this Policy, you may contact us by email at $contactEmail, and we will respond within a reasonable time.',
    ],
  ),
];

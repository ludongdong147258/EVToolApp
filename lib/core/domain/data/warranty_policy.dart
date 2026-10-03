/// 三电质保政策手册（纯静态对照表）
///
/// 移植自 EVTool 小程序 src/lib/warrantyPolicy.js。
/// 整理自各车企官网、随车《保修手册》及公开公告（整理日期见 [warrantyDataDate]）。
/// 各车企政策随车型、购车时间与官方活动动态调整，内容仅供参考，
/// 具体以购车合同及车企最新政策为准。
library;

/// 数据整理日期（YYYY-MM），免责声明与页面角标统一读取此常量
const String warrantyDataDate = '2026-09';

/// 质保对照字段定义（页面渲染顺序即数组顺序）
class WarrantyField {
  const WarrantyField({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;
}

/// 国家规定基线条目
class WarrantyBaselineRule {
  const WarrantyBaselineRule({
    required this.icon,
    required this.label,
    required this.text,
  });

  final String icon;
  final String label;
  final String text;
}

/// 国家规定基线（法定底线 + 2026 年两项新国标，页面 Hero 下方独立卡片）
class WarrantyBaseline {
  const WarrantyBaseline({
    required this.title,
    required this.note,
    required this.rules,
  });

  final String title;
  final String note;
  final List<WarrantyBaselineRule> rules;
}

/// 品牌摘要（列表卡片两行短文案）
class WarrantySummary {
  const WarrantySummary({required this.vehicle, required this.powertrain});

  final String vehicle;
  final String powertrain;
}

/// 单个车企的三电质保政策
class WarrantyBrand {
  const WarrantyBrand({
    required this.id,
    required this.name,
    required this.tagline,
    required this.offersLifetimeWarranty,
    required this.hasDegradationStandard,
    required this.voidsLifetimeOnTransfer,
    required this.summary,
    required this.fields,
  });

  final String id;
  final String name;
  final String tagline;
  final bool offersLifetimeWarranty;
  final bool hasDegradationStandard;
  final bool voidsLifetimeOnTransfer;
  final WarrantySummary summary;

  /// 六个固定展示字段，key 见 [warrantyFields] 的 id
  final Map<String, String> fields;
}

/// 六个固定展示字段（页面渲染顺序即数组顺序）
const List<WarrantyField> warrantyFields = [
  WarrantyField(
    id: 'vehicle',
    label: 'Vehicle warranty',
    icon: 'directions_car',
  ),
  WarrantyField(
    id: 'powertrain',
    label: 'Battery/Motor/Electronics warranty',
    icon: 'battery_charging_full',
  ),
  WarrantyField(
    id: 'lifetime',
    label: 'Lifetime warranty conditions',
    icon: 'verified_user',
  ),
  WarrantyField(
    id: 'degradation',
    label: 'Battery degradation warranty',
    icon: 'science',
  ),
  WarrantyField(
    id: 'transfer',
    label: 'Rights after ownership transfer',
    icon: 'compare_arrows',
  ),
  WarrantyField(id: 'exclusion', label: 'Exclusions', icon: 'warning'),
];

/// 国家规定基线（法定底线 + 2026 年两项新国标，页面 Hero 下方独立卡片）
const WarrantyBaseline warrantyBaseline = WarrantyBaseline(
  title: 'National regulatory baseline',
  note:
      'Manufacturer promises may not fall below the legal minimum; the two new national standards take effect July 1, 2026.',
  rules: [
    WarrantyBaselineRule(
      icon: 'task_alt',
      label: 'Legal warranty minimum',
      text:
          'Passenger-vehicle battery/motor/electronics systems (battery, motor, electronic control) must carry a warranty of at least 8 years or 120,000 km (GB/T 31484 and related national requirements)',
    ),
    WarrantyBaselineRule(
      icon: 'battery_charging_full',
      label: 'New battery durability standard',
      text:
          'GB/T 46991.1-2025 (effective 2026-07-01): battery capacity must remain at or above 82% after 5 years or 100,000 km, and at or above 75% after 8 years or 160,000 km; battery health must be shown to consumers',
    ),
    WarrantyBaselineRule(
      icon: 'whatshot',
      label: 'New battery safety standard',
      text:
          'GB 38031-2025 (effective 2026-07-01): "no fire, no explosion" after thermal runaway becomes a mandatory requirement, replacing the old "5-minute escape" rule',
    ),
  ],
);

/// 主流车企三电质保政策对照（渲染顺序即数组顺序）
const List<WarrantyBrand> warrantyBrands = [
  WarrantyBrand(
    id: 'byd',
    name: 'BYD',
    tagline:
        'Lifetime battery/motor/electronics warranty for first owners (with conditions)',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 6yr/150k km',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 6 years or 150,000 km (whichever comes first)',
      'powertrain':
          'Lifetime warranty on the power battery and cells for non-commercial first owners; the motor, electronic control and other battery/motor/electronics parts are covered 8 years or 150,000 km',
      'lifetime':
          'First owner only + non-commercial use + scheduled maintenance at authorized service shops per the warranty manual + accident repairs at officially authorized shops; earlier models also capped annual mileage at 30,000 km per rolling 12 months — from September 2025 some newer models have relaxed or removed the annual mileage cap (per the terms at purchase)',
      'degradation':
          'No unified degradation percentage threshold published; whether the power battery qualifies is determined by official inspection',
      'transfer':
          'Lifetime warranty voids on transfer; the power battery reverts to the 8-year/150,000 km warranty that follows the car',
      'exclusion':
          'Missed scheduled maintenance, unauthorized battery/motor/electronics or wiring modifications, accident/flood damage to the battery, long-term deep-discharge storage, commercial use',
    },
  ),
  WarrantyBrand(
    id: 'xpeng',
    name: 'XPeng',
    tagline:
        'Base battery/motor/electronics 8yr/160k km; limited-time perks can upgrade to lifetime',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 5yr/120k km',
      powertrain: 'Powertrain 8yr/160k km',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 5 years or 120,000 km (whichever comes first)',
      'powertrain':
          'Base battery/motor/electronics warranty 8 years or 160,000 km; limited-time ordering perks on some models can upgrade to a lifetime battery/motor/electronics warranty for the first owner (e.g. the 2026 X9 BEV, per official campaign rules)',
      'lifetime':
          'Lifetime upgrade requires first owner + non-commercial use + all maintenance and repairs through official channels + annual mileage limits (per the campaign rules at purchase)',
      'degradation':
          'No unified degradation percentage threshold published; battery warranty eligibility is judged by officially authorized inspection standards',
      'transfer':
          'Lifetime perks end on transfer; the 8-year/160,000 km base battery/motor/electronics warranty follows the car',
      'exclusion':
          'Modifying the battery/motor/electronics system, missed official maintenance, commercial use, motorsport competition, unauthorized post-accident repairs',
    },
  ),
  WarrantyBrand(
    id: 'xiaomi',
    name: 'Xiaomi',
    tagline: 'No lifetime warranty; battery/motor/electronics 8yr/160k km',
    offersLifetimeWarranty: false,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: false,
    summary: WarrantySummary(
      vehicle: 'Vehicle 5yr/100k km',
      powertrain: 'Powertrain 8yr/160k km',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 5 years or 100,000 km (whichever comes first)',
      'powertrain':
          'Power battery and drive system 8 years or 160,000 km (SU7/YU7 series)',
      'lifetime':
          'No lifetime battery/motor/electronics policy; even first owners follow the fixed year/mileage terms',
      'degradation':
          'No unified degradation threshold published; per the User Manual and public materials, capacity fade beyond 30% (retention below 70%) within the warranty period qualifies for official inspection, with official judgment as final',
      'transfer':
          'Warranty follows the car, not the owner; the remaining year/mileage coverage stays valid after transfer',
      'exclusion':
          'Unauthorized modification or disassembly of the battery/motor/electronics, maintenance not per schedule, commercial use, off-road/track abuse, accident damage',
    },
  ),
  WarrantyBrand(
    id: 'zeekr',
    name: 'Zeekr',
    tagline:
        'First-owner lifetime battery/motor/electronics (2026 policy caps 60k km/yr); base 8yr/200k km',
    offersLifetimeWarranty: true,
    hasDegradationStandard: true,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 6yr/150k km',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 6 years or 150,000 km (per each model\'s warranty manual)',
      'powertrain':
          'Lifetime warranty on the battery/motor/electronics (power battery, drive motor, motor controller) for non-commercial first owners; base battery/motor/electronics warranty 8 years or 200,000 km',
      'lifetime':
          'New policy announced December 2025 (transition through March 31, 2026): first owner only + non-commercial use + no more than 60,000 km per year (exemptions apply on request) + maintenance and repairs through official channels per the warranty manual; new orders after the transition follow the new policy',
      'degradation':
          'Published capacity-fade limits: not below 92% within 2 years or 50,000 km, not below 84% within 4 years or 100,000 km, within limits at 8 years or 200,000 km (per official details)',
      'transfer':
          'Lifetime warranty ends on transfer; the 8-year/200,000 km base battery/motor/electronics warranty follows the car',
      'exclusion':
          'Modifying the battery/motor/electronics, missed official maintenance, commercial use, unauthorized post-accident repairs, flooding and external fire damage',
    },
  ),
  WarrantyBrand(
    id: 'nio',
    name: 'NIO',
    tagline:
        'First-owner battery/motor/electronics 10 years, unlimited mileage; BaaS batteries maintained by NIO',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 6yr/150k km',
      powertrain: 'Powertrain 10yr·1st owner',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 6 years or 150,000 km (per the certificate of warranty and order benefits)',
      'powertrain':
          'Battery/motor/electronics system 10 years with unlimited mileage for first owners; for Battery-as-a-Service (BaaS) users, the in-car battery is owned and maintained by NIO',
      'lifetime':
          'First owner only + non-commercial use + no transfer (voids immediately on transfer) + maintenance per official schedules; since 2025 NIO has tightened usage audits — commercial use cancels first-owner-exclusive benefits',
      'degradation':
          'Battery fade for BaaS users is NIO\'s responsibility; for purchased batteries no unified percentage threshold is published, official inspection is final',
      'transfer':
          'First-owner-exclusive coverage ends on transfer; subsequent owners get the statutory base warranty with the car (per official policy)',
      'exclusion':
          'Commercial use, modifying the battery/motor/electronics, maintenance not per schedule, unauthorized post-accident repairs, battery abuse such as external discharge',
    },
  ),
  WarrantyBrand(
    id: 'tesla',
    name: 'Tesla',
    tagline:
        'Battery/motor/electronics 8yr/160-240k km; 70% capacity retention threshold',
    offersLifetimeWarranty: false,
    hasDegradationStandard: true,
    voidsLifetimeOnTransfer: false,
    summary: WarrantySummary(
      vehicle: 'Vehicle 4yr/80k km',
      powertrain: 'Powertrain 8yr/160-240k km',
    ),
    fields: {
      'vehicle':
          'Basic vehicle warranty 4 years or 80,000 km (whichever comes first)',
      'powertrain':
          'Battery and drive unit 8 years or 160,000 km (Standard Range); 8 years or 240,000 km (Long Range and Performance, model-dependent)',
      'lifetime':
          'No lifetime warranty policy; all coverage follows fixed year/mileage terms',
      'degradation':
          'Within the battery/motor/electronics warranty, a claim can be filed if capacity retention falls below 70% (the 70% threshold is officially documented)',
      'transfer':
          'Warranty follows the car (bound to the VIN); remaining coverage stays valid after transfer',
      'exclusion':
          'Normal battery degradation (above the 70% threshold), unauthorized battery disassembly or modification, collision/flood damage, track and other abuse',
    },
  ),
  WarrantyBrand(
    id: 'geely',
    name: 'Geely',
    tagline:
        'Galaxy series first owners can get a lifetime battery/motor/electronics warranty',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 6yr/150k km',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Galaxy/Geometry and other NEV series mostly 6 years or 150,000 km (per each model\'s warranty manual)',
      'powertrain':
          'Lifetime battery/motor/electronics warranty for first non-commercial owners of Galaxy and other NEV series; models not qualifying for lifetime get a base 8-year/120,000 km battery/motor/electronics warranty (per each model\'s warranty manual)',
      'lifetime':
          'First owner only + non-commercial use + official maintenance per the warranty manual + annual mileage limits (per the warranty manual)',
      'degradation':
          'No unified degradation percentage threshold published; the power battery is judged by officially authorized inspection',
      'transfer':
          'Lifetime benefits void on transfer; the base battery/motor/electronics warranty follows the car',
      'exclusion':
          'Modifying the battery/motor/electronics, missed official maintenance, commercial use, unauthorized post-accident repairs, water ingress/case damage to the battery',
    },
  ),
  WarrantyBrand(
    id: 'aito',
    name: 'AITO',
    tagline:
        'First non-commercial owner lifetime battery/motor/electronics; base 8yr/160k km',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 4yr/100k km',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 4 years or 100,000 km (per each model\'s warranty manual)',
      'powertrain':
          'Battery/motor/electronics system and range extender 8 years or 160,000 km; first non-commercial owners can get a lifetime battery/motor/electronics warranty (per benefits at purchase)',
      'lifetime':
          'First owner only + non-commercial use + maintenance and repairs through official channels per the warranty manual; the manufacturer promises free replacement for power battery faults, abnormal degradation, or fire/self-ignition (per official terms)',
      'degradation':
          'Free replacement promised for abnormal battery degradation; no unified percentage threshold published, official inspection is final',
      'transfer':
          'Lifetime warranty ends on transfer; the 8-year/160,000 km base battery/motor/electronics warranty follows the car',
      'exclusion':
          'Modifying the battery/motor/electronics, missed official maintenance, commercial use, unauthorized post-accident repairs, external fire/flood damage',
    },
  ),
  WarrantyBrand(
    id: 'lixiang',
    name: 'Li Auto',
    tagline:
        'Lifetime warranty dropped from Feb 2022; base battery/motor/electronics 8yr/160k km',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 5yr/100k km',
      powertrain: 'Powertrain 8yr/160k km',
    ),
    fields: {
      'vehicle':
          'Vehicle warranty 5 years or 100,000 km (whichever comes first)',
      'powertrain':
          'Battery/motor/electronics system (incl. range extender on EREVs) 8 years or 160,000 km (L series/i8 and other current models; Li ONE is 8 years or 120,000 km); first owners who bought before February 1, 2022 keep the lifetime battery/motor/electronics and range-extender warranty',
      'lifetime':
          'New purchases no longer include a standard lifetime warranty; since July 2024 a lifetime vehicle + battery/motor/electronics warranty (no year/mileage limit) can be purchased; Li ONE owners trading in for a new car receive the corresponding lifetime benefits (the "relay program", window through December 31, 2026)',
      'degradation':
          'No unified degradation percentage threshold published; the warranty manual terms and official inspection are final',
      'transfer':
          'Lifetime warranty does not follow the car; after transfer the remaining base battery/motor/electronics coverage applies',
      'exclusion':
          'Modifying the battery/motor/electronics, missed official maintenance, commercial use, unauthorized post-accident repairs, off-road/track abuse',
    },
  ),
  WarrantyBrand(
    id: 'leapmotor',
    name: 'Leapmotor',
    tagline:
        'First non-commercial owners: "four lifetime free warranties" (incl. the vehicle)',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle Lifetime·1st owner',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Lifetime free vehicle warranty for first non-commercial owners (per benefits at purchase)',
      'powertrain':
          'Lifetime free warranty on battery, e-drive and electronic control for first non-commercial owners',
      'lifetime':
          'First owner only + non-commercial use + maintenance and repairs through official channels per the warranty manual (per benefit terms at purchase); since April 2025 some first owners of older models bought through official channels have also been granted the lifetime battery/motor/electronics warranty retroactively',
      'degradation':
          'No unified degradation percentage threshold published; the warranty manual terms and official inspection are final',
      'transfer':
          'Lifetime warranty voids on transfer; the base warranty follows the car (per the warranty manual)',
      'exclusion':
          'Commercial use, modifying the battery/motor/electronics, missed official maintenance, unauthorized post-accident repairs',
    },
  ),
  WarrantyBrand(
    id: 'aion',
    name: 'Aion',
    tagline:
        'First non-commercial owner lifetime battery/motor/electronics (some models cap 30k km/yr)',
    offersLifetimeWarranty: true,
    hasDegradationStandard: false,
    voidsLifetimeOnTransfer: true,
    summary: WarrantySummary(
      vehicle: 'Vehicle 4yr/150k km',
      powertrain: 'Powertrain Lifetime·1st owner',
    ),
    fields: {
      'vehicle':
          'Most models: vehicle warranty 4 years or 150,000 km; some newer models include a lifetime vehicle warranty for first owners (per the purchase contract)',
      'powertrain':
          'Lifetime battery/motor/electronics warranty for first non-commercial owners; base battery/motor/electronics warranty 8 years or 150,000 km (per each model\'s warranty manual)',
      'lifetime':
          'First private owner only + non-commercial use + repairs and maintenance with original parts through official channels per the warranty manual + no more than 30,000 km per calendar year, otherwise coverage drops to the base warranty (per terms at purchase)',
      'degradation':
          'No unified degradation threshold published; AION S/V/Y vehicles with CALB 177Ah batteries get a special warranty upgrade: for private commercial-use vehicles the battery warranty extends from 8 years/150,000 km to 8 years/300,000 km, with free inspection and repair/replacement based on results (per official announcements)',
      'transfer':
          'Lifetime warranty voids on transfer; the base battery/motor/electronics warranty follows the car',
      'exclusion':
          'Commercial use, modifying the battery/motor/electronics, missed official maintenance, unauthorized post-accident repairs, exceeding the annual mileage cap (some models)',
    },
  ),
];

/// 页面底部免责声明
const String warrantyDisclaimer =
    'Compiled from manufacturers\' public official documents and national/industry '
    'standards (as of $warrantyDataDate). For reference only — your purchase '
    'contract and the manufacturer\'s latest policy prevail.';

/// 按品牌 id 取品牌（页面锚点跳转与单测用），未命中返回 null
WarrantyBrand? getBrandById(String id) {
  for (final brand in warrantyBrands) {
    if (brand.id == id) {
      return brand;
    }
  }
  return null;
}

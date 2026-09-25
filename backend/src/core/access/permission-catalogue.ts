/**
 * Standard Permission Catalogue matching the BA-approved ERP UI
 * 10 Functional Modules × 9 Granular Actions
 */
export const ERP_MODULES = [
  'dashboard',
  'inventory',
  'purchase',
  'production',
  'sales',
  'payments',
  'masters',
  'reports',
  'settings',
  'userManagement',
] as const;

export type ErpModule = typeof ERP_MODULES[number];

export const ERP_ACTIONS = [
  'view',
  'create',
  'edit',
  'delete',
  'approve',
  'cancel',
  'export',
  'print',
  'share',
] as const;

export type ErpAction = typeof ERP_ACTIONS[number];

export interface SystemPermission {
  readonly id: string;
  readonly module: ErpModule;
  readonly action: ErpAction;
  readonly description: string;
}

export function generateAllPermissions(): SystemPermission[] {
  const permissions: SystemPermission[] = [];
  for (const mod of ERP_MODULES) {
    for (const act of ERP_ACTIONS) {
      permissions.push({
        id: `${mod}.${act}`,
        module: mod,
        action: act,
        description: `Permission to ${act} in ${mod} module`,
      });
    }
  }
  return permissions;
}

export const ALL_SYSTEM_PERMISSIONS = generateAllPermissions();
export const ALL_PERMISSION_IDS: ReadonlySet<string> = new Set(ALL_SYSTEM_PERMISSIONS.map((p) => p.id));
export const CANONICAL_PERMISSIONS = ALL_SYSTEM_PERMISSIONS;
export type CanonicalPermission = SystemPermission;


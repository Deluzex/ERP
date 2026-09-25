export interface RequestContext {
  readonly userId: string;
  readonly userName: string;
  readonly roleId: string;
  readonly branchIds: readonly string[];
  readonly stockLocationIds: readonly string[];
  readonly permissions: ReadonlySet<string>;
  readonly correlationId: string;
  readonly ipAddress?: string;
}

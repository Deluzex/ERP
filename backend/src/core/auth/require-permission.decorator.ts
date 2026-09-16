import { CustomDecorator, SetMetadata } from '@nestjs/common';
import { REQUIRED_PERMISSIONS_KEY } from './auth.constants';

export const RequirePermission = (...permissions: string[]): CustomDecorator =>
  SetMetadata(REQUIRED_PERMISSIONS_KEY, permissions);

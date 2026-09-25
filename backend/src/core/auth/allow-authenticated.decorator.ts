import { SetMetadata } from '@nestjs/common';
import { ALLOW_AUTHENTICATED_KEY } from './auth.constants';

export const AllowAuthenticated = () => SetMetadata(ALLOW_AUTHENTICATED_KEY, true);

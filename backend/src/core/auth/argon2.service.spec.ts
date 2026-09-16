import { Argon2Service } from './argon2.service';

describe('Argon2Service', () => {
  let service: Argon2Service;

  beforeEach(() => {
    service = new Argon2Service();
  });

  it('should hash a password and verify it successfully', async () => {
    const password = 'SecurePassword@2026';
    const hash = await service.hash(password);

    expect(hash).toBeDefined();
    expect(hash.startsWith('$argon2id$')).toBe(true);

    const isValid = await service.verify(hash, password);
    expect(isValid).toBe(true);
  });

  it('should reject an incorrect password', async () => {
    const password = 'SecurePassword@2026';
    const hash = await service.hash(password);

    const isValid = await service.verify(hash, 'WrongPassword@123');
    expect(isValid).toBe(false);
  });
});

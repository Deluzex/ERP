import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { UpdateMasterStatusDto } from './master-status.dto';

describe('UpdateMasterStatusDto', () => {
  async function validateDto(payload: Record<string, unknown>) {
    const dto = plainToInstance(UpdateMasterStatusDto, payload);
    const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
    return { dto, errors };
  }

  it('accepts valid isActive = true', async () => {
    const { dto, errors } = await validateDto({ isActive: true });
    expect(errors).toHaveLength(0);
    expect(dto.isActive).toBe(true);
  });

  it('accepts valid isActive = false', async () => {
    const { dto, errors } = await validateDto({ isActive: false });
    expect(errors).toHaveLength(0);
    expect(dto.isActive).toBe(false);
  });

  it('rejects missing isActive', async () => {
    const { errors } = await validateDto({});
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('isActive');
  });

  it('rejects non-boolean isActive string', async () => {
    const { errors } = await validateDto({ isActive: 'true' });
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('isActive');
  });

  it('rejects non-boolean isActive number', async () => {
    const { errors } = await validateDto({ isActive: 1 });
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('isActive');
  });

  it('rejects non-boolean isActive null/undefined', async () => {
    const { errors: nullErrors } = await validateDto({ isActive: null });
    expect(nullErrors.length).toBeGreaterThan(0);
  });
});


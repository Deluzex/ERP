import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateCustomerDto, UpdateCustomerDto } from './customer.dto';

const base = { name: 'Kamal', mobile: '9898011223', address: 'Ahmedabad' };

async function createEmail(email: unknown) {
  const dto = plainToInstance(CreateCustomerDto, { ...base, email });
  const errors = await validate(dto, { whitelist: true, forbidNonWhitelisted: true });
  return { dto, errors };
}

describe('Customer email (DTO)', () => {
  const valid: Array<[string, string]> = [
    ['kamal@gmail.com', 'kamal@gmail.com'],
    ['KAMAL@GMAIL.COM', 'kamal@gmail.com'],
    ['kamal.patel@gmail.com', 'kamal.patel@gmail.com'],
    ['Kamal.Patel@gmail.com', 'kamal.patel@gmail.com'],
    ['kamal.patel+erp@gmail.com', 'kamal.patel+erp@gmail.com'],
    ['accounts@company.com', 'accounts@company.com'],
    ['accounts@company.co.in', 'accounts@company.co.in'],
    ['user123@outlook.com', 'user123@outlook.com'],
    ['info@my-company.com', 'info@my-company.com'],
    ['  KAMAL.PATEL@GMAIL.COM  ', 'kamal.patel@gmail.com'],
    ['a@internal-corp.example.org', 'a@internal-corp.example.org'],
  ];

  it.each(valid)('accepts and normalizes %j', async (input, expected) => {
    const { dto, errors } = await createEmail(input);
    expect(errors).toHaveLength(0);
    expect(dto.email).toBe(expected);
  });

  const invalid = [
    'kamalgmail.com',
    'kamal@@gmail.com',
    '@gmail.com',
    'kamal@',
    'kamal @gmail.com',
    'kam al@gmail.com',
    'kamal@gmail',
    'kamal@-gmail.com',
    'kamal@gmail..com',
    'kamal@.com',
    '',
    '   ',
    'a@b@c.com',
  ];

  it.each(invalid)('rejects %j', async (input) => {
    const { errors } = await createEmail(input);
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('email');
  });

  it('rejects non-string values', async () => {
    for (const v of [undefined, null, 123, {}, ['a@b.com']]) {
      const { errors } = await createEmail(v);
      expect(errors.length).toBeGreaterThan(0);
    }
  });

  it('enforces the 254 character maximum', async () => {
    const label = (n: number) => 'x'.repeat(n);
    const domain = `${label(63)}.${label(63)}.${label(60)}.com`;
    const at254 = `${'l'.repeat(254 - domain.length - 1)}@${domain}`;
    expect(at254).toHaveLength(254);
    const over = await createEmail(`${'l'.repeat(64)}@${label(63)}.${label(63)}.${label(63)}.${label(10)}.com`);
    expect(over.errors.length).toBeGreaterThan(0);
    const tooLong = await createEmail(`a@${'b'.repeat(250)}.com`);
    expect(tooLong.errors.length).toBeGreaterThan(0);
    expect(JSON.stringify(tooLong.errors[0].constraints)).toContain('maxLength');
  });

  it('update: normalizes valid email, rejects invalid, allows omission', async () => {
    const ok = plainToInstance(UpdateCustomerDto, { email: '  New@Company.CO.in ' });
    expect(await validate(ok)).toHaveLength(0);
    expect(ok.email).toBe('new@company.co.in');

    const bad = plainToInstance(UpdateCustomerDto, { email: 'nope@@x.com' });
    expect((await validate(bad)).length).toBeGreaterThan(0);

    const blank = plainToInstance(UpdateCustomerDto, { email: '   ' });
    expect((await validate(blank)).length).toBeGreaterThan(0);

    const omitted = plainToInstance(UpdateCustomerDto, { name: 'X' });
    expect(await validate(omitted)).toHaveLength(0);
  });
});

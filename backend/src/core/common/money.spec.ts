import { Money } from './money';

describe('Money utility (ADR-011)', () => {
  it('should format currency with exactly 2 decimal places', () => {
    expect(Money.format('100')).toBe('100.00');
    expect(Money.format('100.5')).toBe('100.50');
    expect(Money.format('100.556')).toBe('100.56');
    expect(Money.format(250.75)).toBe('250.75');
    expect(Money.format('invalid')).toBe('0.00');
  });

  it('should format inventory quantities with exactly 4 decimal places', () => {
    expect(Money.formatQuantity('12')).toBe('12.0000');
    expect(Money.formatQuantity('12.345')).toBe('12.3450');
    expect(Money.formatQuantity(0.0025)).toBe('0.0025');
    expect(Money.formatQuantity('invalid')).toBe('0.0000');
  });

  it('should validate money strings properly', () => {
    expect(Money.isValidMoneyString('150.00')).toBe(true);
    expect(Money.isValidMoneyString('150.5')).toBe(true);
    expect(Money.isValidMoneyString('150')).toBe(true);
    expect(Money.isValidMoneyString('-150.00')).toBe(false);
    expect(Money.isValidMoneyString('150.999')).toBe(false);
    expect(Money.isValidMoneyString('abc')).toBe(false);
  });

  it('should validate quantity strings properly', () => {
    expect(Money.isValidQuantityString('10')).toBe(true);
    expect(Money.isValidQuantityString('10.1234')).toBe(true);
    expect(Money.isValidQuantityString('10.12345')).toBe(false);
    expect(Money.isValidQuantityString('-5')).toBe(false);
  });
});

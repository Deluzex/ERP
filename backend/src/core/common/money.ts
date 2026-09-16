/**
 * Money and Decimal Utilities (ADR-011)
 * Never use floating-point types for currency or stock quantities.
 * Handled as fixed-scale strings in API boundaries.
 */
export class Money {
  /**
   * Format a decimal string or numeric value to standard 2-decimal currency string
   */
  static format(amount: string | number): string {
    const parsed = typeof amount === 'number' ? amount : parseFloat(amount);
    if (isNaN(parsed)) {
      return '0.00';
    }
    return parsed.toFixed(2);
  }

  /**
   * Format a stock quantity to 4 decimal places
   */
  static formatQuantity(quantity: string | number): string {
    const parsed = typeof quantity === 'number' ? quantity : parseFloat(quantity);
    if (isNaN(parsed)) {
      return '0.0000';
    }
    return parsed.toFixed(4);
  }

  /**
   * Validate that an input string represents a valid non-negative decimal amount
   */
  static isValidMoneyString(value: string): boolean {
    return /^\d+(\.\d{1,2})?$/.test(value);
  }

  /**
   * Validate that an input string represents a valid non-negative quantity
   */
  static isValidQuantityString(value: string): boolean {
    return /^\d+(\.\d{1,4})?$/.test(value);
  }
}

import { v4 as uuidv4 } from 'uuid';

export class IdGenerator {
  static uuid(): string {
    return uuidv4();
  }

  static docNumber(prefix: string, sequenceNumber: number): string {
    const year = new Date().getFullYear();
    const seq = sequenceNumber.toString().padStart(4, '0');
    return `${prefix}-${year}-${seq}`;
  }
}

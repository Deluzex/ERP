import { Injectable, LoggerService as INestLogger } from '@nestjs/common';

@Injectable()
export class AppLogger implements INestLogger {
  private formatLog(level: string, message: unknown, context?: string, correlationId?: string): string {
    const timestamp = new Date().toISOString();
    const logObj = {
      timestamp,
      level,
      context: context || 'Application',
      correlationId: correlationId || undefined,
      message: typeof message === 'object' ? message : String(message),
    };
    return JSON.stringify(logObj);
  }

  log(message: unknown, context?: string, correlationId?: string): void {
    console.log(this.formatLog('INFO', message, context, correlationId));
  }

  error(message: unknown, trace?: string, context?: string, correlationId?: string): void {
    const timestamp = new Date().toISOString();
    const logObj = {
      timestamp,
      level: 'ERROR',
      context: context || 'Application',
      correlationId: correlationId || undefined,
      message: typeof message === 'object' ? message : String(message),
      trace: trace || undefined,
    };
    console.error(JSON.stringify(logObj));
  }

  warn(message: unknown, context?: string, correlationId?: string): void {
    console.warn(this.formatLog('WARN', message, context, correlationId));
  }

  debug(message: unknown, context?: string, correlationId?: string): void {
    if (process.env.NODE_ENV !== 'production') {
      console.debug(this.formatLog('DEBUG', message, context, correlationId));
    }
  }

  verbose(message: unknown, context?: string, correlationId?: string): void {
    if (process.env.NODE_ENV !== 'production') {
      console.log(this.formatLog('VERBOSE', message, context, correlationId));
    }
  }
}

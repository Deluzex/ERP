import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AppLogger } from './core/logging/logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });

  const logger = app.get(AppLogger);
  app.useLogger(logger);

  const config = app.get(ConfigService);
  const port = config.get<number>('PORT') || 3000;
  const apiPrefix = config.get<string>('API_PREFIX') || '/api/v1';

  // Security Headers
  app.use(helmet());

  // CORS Configuration
  app.enableCors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
  });

  // Global Routing Prefix
  app.setGlobalPrefix(apiPrefix.replace(/^\/+|\/+$/g, ''));

  // Global Input Validation Pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  await app.listen(port);
  logger.log(
    `🚀 Deluzex ERP Backend running on http://localhost:${port}/${apiPrefix.replace(/^\/+|\/+$/g, '')}`,
    'Bootstrap',
  );
}

bootstrap();

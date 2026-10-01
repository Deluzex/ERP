import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
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

  // Security Headers (CSP relaxed for Swagger UI CDN assets)
  app.use(
    helmet({
      contentSecurityPolicy: false,
    }),
  );

  // CORS Configuration
  const corsOrigin = config.get<string>('CORS_ORIGIN');
  let allowedOrigins: boolean | string | string[] = true;

  if (process.env.NODE_ENV === 'production' && corsOrigin) {
    allowedOrigins = corsOrigin.includes(',')
      ? corsOrigin.split(',').map((o) => o.trim())
      : corsOrigin.trim();
  }

  app.enableCors({
    origin: allowedOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
  });

  // Global Routing Prefix
  app.setGlobalPrefix(apiPrefix.replace(/^\/+|\/+$/g, ''));

  // Root redirect to Swagger Documentation
  app.getHttpAdapter().get('/', (_req: any, res: any) => {
    res.redirect('/api/docs');
  });

  // Version check endpoint for deployment verification
  app.getHttpAdapter().get('/api/v1/version', (_req: any, res: any) => {
    res.json({
      app: 'Deluzex ERP API',
      version: '1.0.1',
      status: 'healthy',
      environment: process.env.NODE_ENV || 'production',
      deployedOn: 'Vercel',
    });
  });

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

  // Swagger Documentation Setup
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Deluzex ERP API — v1.0.1')
    .setDescription('Production-grade enterprise manufacturing & inventory management REST APIs (Vercel Live v1.0.1)')
    .setVersion('1.0.1')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'Authorization',
        description: 'Enter your Bearer access token',
        in: 'header',
      },
      'JWT-auth',
    )
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  const swaggerOptions = {
    customSiteTitle: 'Deluzex ERP — Swagger API Docs',
    customCssUrl: [
      'https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.20.0/swagger-ui.min.css',
    ],
    customJs: [
      'https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.20.0/swagger-ui-bundle.js',
      'https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.20.0/swagger-ui-standalone-preset.js',
    ],
    swaggerOptions: {
      persistAuthorization: true,
      displayRequestDuration: true,
      filter: true,
    },
  };

  SwaggerModule.setup('api/docs', app, document, swaggerOptions);
  SwaggerModule.setup('docs', app, document, swaggerOptions);

  await app.listen(port, '0.0.0.0');
  logger.log(
    `🚀 Deluzex ERP Backend running on http://localhost:${port}/${apiPrefix.replace(/^\/+|\/+$/g, '')}`,
    'Bootstrap',
  );
  logger.log(
    `📚 Swagger API Documentation available at http://localhost:${port}/api/docs`,
    'Bootstrap',
  );
}

bootstrap();

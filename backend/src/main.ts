import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Libera o front-end (React, em outra origem) a consumir a API pelo navegador
  app.enableCors();

  // Ativa as validações dos DTOs (class-validator) globalmente
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // remove campos que não existem no DTO
      transform: true, // converte tipos automaticamente
    }),
  );

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
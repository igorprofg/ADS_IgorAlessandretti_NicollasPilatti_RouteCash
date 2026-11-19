import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { WebhooksController } from './webhooks.controller';
import { WebhooksService } from './webhooks.service';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
  ],
  controllers: [
    WebhooksController,
  ],
  providers: [
    WebhooksService,
  ],
  exports: [
    WebhooksService,
  ],
})
export class WebhooksModule {}

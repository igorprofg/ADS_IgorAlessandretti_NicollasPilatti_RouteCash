import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { WebhooksService } from './webhooks.service';

@Controller('webhooks/asaas')
export class WebhooksController {
  constructor(
    private readonly webhooksService: WebhooksService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  receberEvento(
    @Headers('asaas-access-token')
    asaasAccessToken: string | undefined,

    @Body()
    payload: unknown,
  ) {
    return this.webhooksService.receberEventoAsaas(
      asaasAccessToken,
      payload,
    );
  }
}

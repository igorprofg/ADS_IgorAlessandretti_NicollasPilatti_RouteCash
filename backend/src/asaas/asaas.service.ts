import {
  Injectable,
  InternalServerErrorException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AsaasService {
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly userAgent: string;

  constructor(private readonly configService: ConfigService) {
    this.baseUrl = (
      this.configService.get<string>('ASAAS_BASE_URL') ??
      'https://api-sandbox.asaas.com/v3'
    ).replace(/\/$/, '');

    this.apiKey =
      this.configService.get<string>('ASAAS_API_KEY')?.trim() ?? '';

    this.userAgent =
      this.configService.get<string>('ASAAS_USER_AGENT')?.trim() ??
      'RouteCash/1.0';
  }

  private getHeaders(): Record<string, string> {
    if (!this.apiKey) {
      throw new InternalServerErrorException(
        'ASAAS_API_KEY não está configurada no .env.',
      );
    }

    return {
      accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': this.userAgent,
      access_token: this.apiKey,
    };
  }

  async testarConexao() {
    try {
      const response = await fetch(
        `${this.baseUrl}/customers?limit=1`,
        {
          method: 'GET',
          headers: this.getHeaders(),
        },
      );

      if (response.status === 401) {
        throw new UnauthorizedException(
          'API Key do Asaas inválida ou incompatível com o Sandbox.',
        );
      }

      if (!response.ok) {
        const body = await response.text();

        throw new InternalServerErrorException(
          `Erro ao comunicar com o Asaas. HTTP ${response.status}: ${body}`,
        );
      }

      const data = await response.json();

      return {
        sucesso: true,
        ambiente: 'SANDBOX',
        mensagem: 'Conexão com o Asaas realizada com sucesso.',
        resposta: data,
      };
    } catch (error) {
      if (
        error instanceof UnauthorizedException ||
        error instanceof InternalServerErrorException
      ) {
        throw error;
      }

      throw new InternalServerErrorException(
        `Não foi possível conectar ao Asaas: ${
          error instanceof Error ? error.message : 'Erro desconhecido'
        }`,
      );
    }
  }
}
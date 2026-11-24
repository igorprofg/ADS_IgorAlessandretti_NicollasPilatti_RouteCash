import { Module } from '@nestjs/common';
import { DadosPagamentoController } from './dados-pagamento.controller';
import { DadosPagamentoService } from './dados-pagamento.service';

@Module({
  controllers: [DadosPagamentoController],
  providers: [DadosPagamentoService],
})
export class DadosPagamentoModule {}
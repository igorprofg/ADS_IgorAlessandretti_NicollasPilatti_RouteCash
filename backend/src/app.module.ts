import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { AutenticacaoModule } from './autenticacao/autenticacao.module';
import { VeiculosModule } from './veiculos/veiculos.module';
import { PlataformasModule } from './plataformas/plataformas.module';
import { GanhosModule } from './ganhos/ganhos.module';
import { DespesasModule } from './despesas/despesas.module';
import { CategoriasDespesaModule } from './categorias-despesa/categorias-despesa.module';
import { JornadasModule } from './jornadas/jornadas.module';
import { QuilometragemModule } from './quilometragem/quilometragem.module';
import { IndicadoresModule } from './indicadores/indicadores.module';
import { SincronizacaoModule } from './sincronizacao/sincronizacao.module';
import { PlanosModule } from './planos/planos.module';
import { AssinaturasModule } from './assinaturas/assinaturas.module';
import { PagamentosModule } from './pagamentos/pagamentos.module';
import { AssinantesModule } from './assinantes/assinantes.module';
import { PlanosAdminModule } from './planos-admin/planos-admin.module';
import { AssinaturasAdminModule } from './assinaturas-admin/assinaturas-admin.module';
import { PagamentosAdminModule } from './pagamentos-admin/pagamentos-admin.module';
import { AsaasModule } from './asaas/asaas.module';
import { WebhooksModule } from './webhooks/webhooks.module';



@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    UsuariosModule,
    AutenticacaoModule,
    VeiculosModule,
    PlataformasModule,
    GanhosModule,
    DespesasModule,
    CategoriasDespesaModule,
    JornadasModule,
    QuilometragemModule,
    IndicadoresModule,
    SincronizacaoModule,
    PlanosModule,
    AssinaturasModule,
    PagamentosModule,
    AssinantesModule,
    PlanosAdminModule,
    AssinaturasAdminModule,
    PagamentosAdminModule,
    AsaasModule,
    WebhooksModule,
  ],
})
export class AppModule {}
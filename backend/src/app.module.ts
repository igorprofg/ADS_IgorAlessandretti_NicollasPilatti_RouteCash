import { Module } from '@nestjs/common';
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

@Module({
  imports: [
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
  ],
})
export class AppModule {}
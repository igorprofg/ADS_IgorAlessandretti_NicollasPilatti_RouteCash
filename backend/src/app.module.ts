import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { AutenticacaoModule } from './autenticacao/autenticacao.module';
import { VeiculosModule } from './veiculos/veiculos.module';
import { PlataformasModule } from './plataformas/plataformas.module';
import { GanhosModule } from './ganhos/ganhos.module';
import { DespesasModule } from './despesas/despesas.module';
import { CategoriasDespesaModule } from './categorias-despesa/categorias-despesa.module';

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
  ],
})
export class AppModule {}
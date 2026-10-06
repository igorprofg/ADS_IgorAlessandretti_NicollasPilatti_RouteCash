import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { AutenticacaoModule } from './autenticacao/autenticacao.module';
import { VeiculosModule } from './veiculos/veiculos.module';
import { PlataformasModule } from './plataformas/plataformas.module';

@Module({
  imports: [
    PrismaModule,
    UsuariosModule,
    AutenticacaoModule,
    VeiculosModule,
    PlataformasModule,
  ],
})
export class AppModule {}
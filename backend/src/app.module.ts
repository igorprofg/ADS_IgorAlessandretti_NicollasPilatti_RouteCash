import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { AutenticacaoModule } from './autenticacao/autenticacao.module';

@Module({
  imports: [PrismaModule, UsuariosModule, AutenticacaoModule],
})
export class AppModule {}
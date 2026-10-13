import { Module } from '@nestjs/common';
import { CategoriasDespesaController } from './categorias-despesa.controller';
import { CategoriasDespesaService } from './categorias-despesa.service';

@Module({
  controllers: [CategoriasDespesaController],
  providers: [CategoriasDespesaService],
})
export class CategoriasDespesaModule {}
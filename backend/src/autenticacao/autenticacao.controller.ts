import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { AutenticacaoService } from './autenticacao.service';
import { LoginDto } from './dto/login.dto';

@Controller('autenticacao')
export class AutenticacaoController {
    constructor(private readonly autenticacaoService: AutenticacaoService) {}


    @HttpCode(HttpStatus.OK)
    @Post('login')
    login(@Body() dto: LoginDto) {
        return this.autenticacaoService.login(dto); 

    }
} 

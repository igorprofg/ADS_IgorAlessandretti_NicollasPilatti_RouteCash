import { IsEmail, IsNotEmpty, IsString} from 'class-validator'; 

export class LoginDto {
    @IsEmail({}, { message: 'E-mail inválido'})
    email: string;

    @IsNotEmpty({ message: 'A senha é obrigatória'})
    @IsString()
    senha: string;
}
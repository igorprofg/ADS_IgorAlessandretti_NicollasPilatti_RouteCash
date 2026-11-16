import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  SituacaoAssinatura,
  StatusConta,
  TipoUsuario,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { hojeComoData } from '../common/periodo-cobranca';
import { ConsultarAssinantesDto } from './dto/consultar-assinantes.dto';

export type UsuarioComAssinaturas = Prisma.UsuarioGetPayload<{
  include: { assinaturas: { include: { plano: true } } };
}>;

// Só a assinatura em aberto (ativa ou suspensa) mais recente de cada usuário
const INCLUIR_ASSINATURA_ATUAL = {
  assinaturas: {
    where: {
      situacao: { in: [SituacaoAssinatura.ATIVA, SituacaoAssinatura.SUSPENSA] },
    },
    include: { plano: true },
    orderBy: { data_cadastro: 'desc' as const },
    take: 1,
  },
};

const dia = (data: Date) => data.toISOString().slice(0, 10);

// RF15: o "assinante" é o usuário motorista; a "situação do assinante" é o status_conta
// (ativo, suspenso ou bloqueado). A situação da ASSINATURA (contrato) é assunto do RF17.
@Injectable()
export class AssinantesService {
  constructor(private readonly prisma: PrismaService) {}

  // Nunca devolve senha_hash: só os campos listados aqui saem na resposta
  private serializar(u: UsuarioComAssinaturas) {
    const assinatura = u.assinaturas[0] ?? null;
    return {
      id_usuario: u.id_usuario,
      nome: u.nome,
      email: u.email,
      status_conta: u.status_conta,
      data_cadastro: u.data_cadastro.toISOString(),
      assinatura_atual: assinatura
        ? {
            id_assinatura: assinatura.id_assinatura,
            situacao: assinatura.situacao,
            data_inicio: assinatura.data_inicio ? dia(assinatura.data_inicio) : '',
            data_vencimento: assinatura.data_vencimento ? dia(assinatura.data_vencimento) : '',
            vencida: assinatura.data_vencimento
              ? assinatura.data_vencimento.getTime() < hojeComoData().getTime()
              : false,
            plano: {
              nome: assinatura.plano.nome,
              valor: Number(assinatura.plano.valor),
              periodo_cobranca: assinatura.plano.periodo_cobranca,
            },
          }
        : null,
    };
  }

  private serializarDetalhe(u: UsuarioComAssinaturas) {
    return {
      ...this.serializar(u),
      aceite_termos_em: u.aceite_termos_em.toISOString(),
      data_atualizacao: u.data_atualizacao.toISOString(),
    };
  }

  // Só motoristas são "assinantes": administradores não aparecem e não podem ser alterados por aqui
  private async buscarMotorista(id: string) {
    const usuario = await this.prisma.usuario.findFirst({
      where: { id_usuario: id, tipo_usuario: TipoUsuario.MOTORISTA },
      include: INCLUIR_ASSINATURA_ATUAL,
    });
    if (!usuario) {
      throw new NotFoundException('Assinante não encontrado');
    }
    return usuario;
  }

  // HU41: listar e pesquisar por nome e/ou e-mail (sem diferenciar maiúsculas de minúsculas)
  async listar(filtro: ConsultarAssinantesDto) {
    const pagina = filtro.pagina ?? 1;
    const limite = filtro.limite ?? 20;
    const nome = filtro.nome?.trim();
    const email = filtro.email?.trim();

    const where: Prisma.UsuarioWhereInput = {
      tipo_usuario: TipoUsuario.MOTORISTA,
      ...(nome && { nome: { contains: nome, mode: 'insensitive' as const } }),
      ...(email && { email: { contains: email, mode: 'insensitive' as const } }),
    };

    const [usuarios, total] = await Promise.all([
      this.prisma.usuario.findMany({
        where,
        include: INCLUIR_ASSINATURA_ATUAL,
        orderBy: { nome: 'asc' },
        skip: (pagina - 1) * limite,
        take: limite,
      }),
      this.prisma.usuario.count({ where }),
    ]);

    return {
      itens: usuarios.map((u) => this.serializar(u)),
      total,
      pagina,
      limite,
    };
  }

  // HU41: dados de um assinante
  async buscarUm(id: string) {
    return this.serializarDetalhe(await this.buscarMotorista(id));
  }

  private async alterarStatus(id: string, destino: StatusConta) {
    await this.prisma.usuario.update({
      where: { id_usuario: id },
      data: { status_conta: destino },
    });
    return this.serializarDetalhe(await this.buscarMotorista(id));
  }

  // HU42
  async ativar(id: string) {
    const usuario = await this.buscarMotorista(id);
    if (usuario.status_conta === StatusConta.ATIVO) {
      throw new BadRequestException('O assinante já está ativo');
    }
    return this.alterarStatus(id, StatusConta.ATIVO);
  }

  // HU43: só um assinante ativo pode ser suspenso; os dados são preservados
  async suspender(id: string) {
    const usuario = await this.buscarMotorista(id);
    if (usuario.status_conta !== StatusConta.ATIVO) {
      throw new BadRequestException('Somente assinantes ativos podem ser suspensos');
    }
    return this.alterarStatus(id, StatusConta.SUSPENSO);
  }

  // HU44: o acesso é barrado já na próxima requisição (JwtStrategy) e no login; os dados são preservados
  async bloquear(id: string) {
    const usuario = await this.buscarMotorista(id);
    if (usuario.status_conta === StatusConta.BLOQUEADO) {
      throw new BadRequestException('O assinante já está bloqueado');
    }
    return this.alterarStatus(id, StatusConta.BLOQUEADO);
  }
}
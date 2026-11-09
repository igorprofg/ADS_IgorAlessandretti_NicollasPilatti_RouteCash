# Route Cash — Relatório Técnico de Finalização do Aplicativo Mobile

**Projeto:** Route Cash  
**Módulo:** Aplicativo Mobile  
**Stack principal:** Flutter / Dart / Riverpod / Dio / SQLite / Secure Storage  
**Data do registro:** 09/11/2026  
**Status geral:** etapa mobile considerada funcionalmente concluída para o escopo acadêmico atual, restando apenas a validação prática final do fluxo de PIN/biometria no aparelho real.

---

## 1. Objetivo deste documento

Este documento consolida a finalização da parte mobile do projeto **Route Cash**, registrando as funcionalidades implementadas, decisões de arquitetura, fluxos offline, sincronização, segurança, identidade visual, arquivos alterados e pontos de validação.

Ele deve servir como histórico técnico do projeto, referência para manutenção, apoio para apresentação acadêmica e documentação da entrega final do aplicativo mobile.

A principal característica consolidada nesta etapa é o funcionamento **local-first**: o motorista consegue realizar as operações mais importantes mesmo sem internet, mantendo os dados no SQLite e sincronizando posteriormente com o backend.

---

## 2. Visão geral da arquitetura mobile

O aplicativo utiliza:

- Flutter e Dart;
- Riverpod para providers e injeção de dependências;
- Dio para chamadas HTTP;
- sqflite para persistência SQLite;
- flutter_secure_storage para sessão e dados locais sensíveis;
- connectivity_plus para apoio à detecção de conectividade;
- uuid para criação de identificadores locais;
- local_auth para biometria;
- crypto para hash do PIN.

A divisão lógica ficou organizada entre:

- apresentação;
- repositórios;
- banco local;
- sincronização;
- autenticação;
- cache;
- segurança;
- integração com a API.

O backend continua sendo a fonte central do sistema, mas o mobile não depende de conectividade contínua para as funcionalidades operacionais do motorista.

---

## 3. Princípio local-first

O funcionamento principal segue esta lógica:

```text
Usuário realiza uma ação
        ↓
Aplicativo salva no SQLite
        ↓
A alteração é registrada na fila de sincronização
        ↓
A interface já considera a operação concluída
        ↓
Quando o backend estiver disponível:
        ↓
SyncManager envia pendências
        ↓
Servidor processa
        ↓
Mobile baixa snapshot atualizado
        ↓
Banco local é reconciliado
```

Com isso, uma perda de internet não impede o motorista de registrar ganhos, despesas, jornadas, veículos ou plataformas.

---

## 4. Banco SQLite separado por usuário

Cada usuário possui sua própria base local, no formato:

```text
route_cash_<id_usuario>.db
```

A base correta é aberta com:

```dart
AppDatabase.instance.useUser(userId);
```

Ao encerrar uma sessão:

```dart
AppDatabase.instance.releaseUser();
```

fecha a base ativa, mas não necessariamente apaga o arquivo.

Essa decisão permite:

- isolamento entre contas;
- preservação dos dados locais;
- retorno do mesmo usuário posteriormente;
- reabertura offline quando a sessão ainda existe;
- prevenção de mistura de registros entre usuários.

---

## 5. Sincronização RF11

A sincronização foi consolidada nos endpoints:

```http
POST /sincronizacao/enviar
GET /sincronizacao/baixar
```

O envio utiliza Bearer Token e trabalha com registros locais pendentes.

Entidades sincronizadas pelo fluxo principal:

- veículos;
- plataformas;
- ganhos;
- despesas;
- jornadas.

Os registros criados no mobile utilizam UUID v4, permitindo criação offline sem depender do servidor para gerar identificadores.

A ordem de envio definida é:

1. veículos;
2. plataformas;
3. ganhos;
4. despesas;
5. jornadas;
6. exclusões.

Essa ordem preserva dependências entre entidades.

---

## 6. Fila de sincronização

O aplicativo mantém uma outbox genérica no SQLite, com campos equivalentes a:

```text
id
entidade
registro_id
operacao
payload_json
estado
codigo_erro
motivo_erro
tentativas
atualizado_em
```

Estados relevantes:

```text
pendente
atencao
sincronizado
```

A combinação `entidade + registro_id` impede múltiplas pendências concorrentes do mesmo registro.

Ao editar um item anteriormente marcado como atenção, o novo upsert pode recolocá-lo em estado pendente.

---

## 7. Tratamento dos retornos da sincronização

O mobile segue o contrato do backend.

### `ok`

O servidor aceitou o registro. A pendência é removida.

### `ignorado / JA_SINCRONIZADO`

O servidor já possui o mesmo registro. A pendência é removida.

### `ignorado / SERVIDOR_MAIS_RECENTE`

O servidor possui estado mais recente. A pendência é removida e o snapshot posterior prevalece.

### `erro / ERRO_INTERNO`

É tratado como temporário. A pendência permanece para nova tentativa.

### `VALIDACAO`, `NAO_ENCONTRADO` ou `CONFLITO`

O registro permanece no mobile e é marcado como necessitando atenção, evitando loop infinito de tentativas.

---

## 8. Reconciliação do snapshot

Depois do envio, o mobile pode baixar um snapshot completo.

A principal regra de segurança da reconciliação é:

> Registros locais com pendência ou atenção não devem ser apagados pelo snapshot.

Isso protege alterações feitas offline antes de chegarem ao servidor.

Veículos e plataformas inativos também fazem parte do snapshot, permitindo reconstruir corretamente o estado local.

---

## 9. Ganhos

O módulo de ganhos ficou com suporte a:

- criação;
- edição;
- duplicação;
- exclusão;
- observação;
- uso offline;
- sincronização posterior;
- reconciliação.

Ao duplicar um ganho é criado um **novo UUID**, garantindo que seja um novo lançamento e não uma edição do original.

Fluxo:

```text
Ganho existente
→ Duplicar
→ Cópia editável
→ Novo UUID
→ Salvar local
→ Outbox
→ Sincronização
```

---

## 10. Despesas

O módulo de despesas também funciona local-first:

- criar;
- editar;
- excluir;
- adicionar observação;
- categorizar;
- associar veículo;
- salvar no SQLite;
- sincronizar depois.

As categorias são tratadas como dados de apoio/cache e não seguem exatamente o mesmo fluxo de criação local das entidades operacionais.

---

## 11. Jornadas e quilometragem

As jornadas suportam:

- início;
- finalização;
- registro offline;
- exclusão;
- pendência;
- sincronização automática após reconexão;
- acompanhamento visual da jornada em andamento;
- atualização do cronômetro;
- uso nos indicadores financeiros.

Foi incorporado o campo:

```text
km_rodados
```

Esse valor é usado para os cálculos por quilômetro.

---

## 12. Indicadores locais

A Home calcula indicadores diretamente a partir do SQLite, permitindo funcionamento offline.

Indicadores:

- faturamento;
- despesas;
- lucro líquido;
- tempo trabalhado;
- quilômetros rodados;
- ganho/hora;
- ganho/km;
- custo/km.

Fórmulas:

```text
lucro líquido = faturamento - despesas

ganho/hora = lucro líquido / horas trabalhadas

ganho/km = lucro líquido / km rodados

custo/km = despesas / km rodados
```

Quando faltam horas ou quilômetros, o aplicativo apresenta o indicador como indisponível em vez de assumir valores artificiais.

A Home também possui filtros:

```text
Dia
Semana
Mês
Ano
```

com navegação entre períodos e retorno para a data atual.

---

## 13. Veículos local-first

O gerenciamento de veículos passou a funcionar offline.

Funcionalidades:

- criar;
- editar;
- desativar;
- reativar;
- definir principal;
- preservar pendências;
- sincronizar depois.

Regras relevantes:

```text
marca: obrigatória, até 50
modelo: obrigatório, até 50
ano: 1950–2100
combustível: obrigatório, até 30
consumo: > 0 e <= 999,99
placa: opcional, até 10 e única
```

Ao desativar um veículo:

```text
principal = false
```

O sistema também mantém apenas um veículo principal por usuário.

A validação de placa duplicada foi testada e funcionou conforme esperado.

---

## 14. Plataformas local-first

As plataformas também foram migradas para o fluxo local-first.

Funcionalidades:

- criação;
- edição;
- ativação/desativação;
- sincronização posterior.

Regras:

```text
nome obrigatório
máximo 60 caracteres
único por usuário sem diferenciar maiúsculas/minúsculas
```

Para plataformas padrão:

- o mobile não controla o nome oficial;
- o campo `padrao` não é enviado;
- o usuário pode alterar o estado ativo;
- o servidor preserva o nome oficial.

Também foram adicionados estados visuais como:

```text
Sincronização pendente
Precisa de atenção
```

---

## 15. Cache do perfil

Foi adicionada estratégia de cache local do usuário.

Tabela conceitual:

```text
usuario_cache
```

Campos:

```text
id_usuario
nome
email
tipo_usuario
status_conta
atualizado_em
raw_json
```

Fluxo esperado:

```text
GET /usuarios/me
→ sucesso
→ atualiza cache
→ retorna perfil
```

Em falha de conectividade ou erro temporário do servidor:

```text
API indisponível
→ consulta usuario_cache
→ usa último perfil conhecido
```

O cache não deve substituir silenciosamente erros 401/403.

Isso permite, entre outras coisas, exibir o nome do motorista na Home mesmo sem internet.

---

## 16. Persistência da sessão offline

O `flutter_secure_storage` armazena:

```text
access_token
id_usuario
```

Após o primeiro login online:

```text
backend autentica
→ salva token
→ salva userId
→ abre SQLite do usuário
→ Home
```

Depois disso, simplesmente fechar o aplicativo não destrói a sessão.

Ao abrir novamente:

```text
AuthGate
→ lê token
→ lê userId
→ abre SQLite
→ continua
```

Nenhuma chamada ao backend é obrigatória apenas para restaurar a sessão.

Isso foi testado com o backend desligado e funcionou.

---

## 17. AuthGate

O `AuthGate` passou a ser a entrada central da aplicação.

Ele decide entre:

```text
Splash
LoginPage
AppLockPage
HomePage
```

Fluxo final:

```text
Aplicativo abre
      ↓
Splash
      ↓
Existe token + userId?
   não ↓        ↓ sim
 Login      abre SQLite
                ↓
         bloqueio ativo?
          não ↓   ↓ sim
          Home   AppLockPage
```

---

## 18. Diferença entre fechar, bloquear e sair

Foram definidos três comportamentos diferentes.

### Fechar o aplicativo

Mantém:

- token;
- userId;
- SQLite;
- sessão.

Pode reabrir offline.

### Bloquear aplicativo

Mantém:

- token;
- userId;
- SQLite;
- sessão.

Mas exige PIN ou biometria para acessar a interface.

### Sair da conta

Executa logout real:

- interrompe AutoSync;
- cancela listeners;
- fecha SQLite;
- remove token;
- remove userId;
- volta para login.

Depois do logout, um novo login exige backend.

---

## 19. Decisão de não armazenar senha

Foi avaliada a ideia de permitir login offline usando e-mail e senha depois de um logout.

Essa abordagem foi descartada.

O aplicativo **não deve guardar a senha normal do Route Cash no dispositivo** apenas para reproduzir uma autenticação offline.

A solução escolhida foi:

- sessão persistente enquanto o usuário não sair;
- bloqueio local separado;
- PIN;
- biometria;
- logout real quando solicitado.

---

## 20. PIN local

O bloqueio local utiliza PIN de 4 a 6 números.

O PIN não é salvo em texto puro.

São armazenados:

```text
salt aleatório
hash SHA-256
```

Estrutura:

```text
salt + PIN
→ SHA-256
→ hash
```

As configurações são separadas por usuário:

```text
app_lock_enabled_<userId>
app_biometric_enabled_<userId>
app_pin_hash_<userId>
app_pin_salt_<userId>
```

---

## 21. AppLockService

Novo arquivo:

```text
lib/core/security/app_lock_service.dart
```

Responsabilidades:

- identificar usuário atual;
- gerar salt;
- gerar hash;
- configurar PIN;
- validar PIN;
- consultar bloqueio;
- ativar/desativar bloqueio;
- verificar disponibilidade de biometria;
- solicitar biometria;
- ativar/desativar biometria.

Centralizar isso em um serviço evita espalhar regras de segurança pelas telas.

---

## 22. Tela de configuração de PIN

Novo arquivo:

```text
lib/features/auth/presentation/setup_pin_page.dart
```

Responsabilidades:

- cadastrar PIN;
- confirmar PIN;
- limitar a 4–6 dígitos;
- aceitar apenas números;
- permitir alteração posterior;
- ativar bloqueio.

---

## 23. Tela de bloqueio

Novo arquivo:

```text
lib/features/auth/presentation/app_lock_page.dart
```

A tela possui:

- logo Route Cash;
- indicação de aplicativo bloqueado;
- PIN;
- botão desbloquear;
- biometria, quando disponível;
- opção de sair da conta.

Se a biometria falhar ou for cancelada, o PIN continua disponível.

A autenticação local não depende da internet.

---

## 24. Biometria

Foi incorporado:

```yaml
local_auth: ^3.0.1
```

Essa versão foi escolhida por compatibilidade com o Dart atual:

```yaml
sdk: ^3.9.2
```

Também foi incluído:

```yaml
crypto: ^3.0.8
```

para hash do PIN.

No Android foi necessário alterar:

```text
FlutterActivity
```

para:

```text
FlutterFragmentActivity
```

em:

```text
android/app/src/main/kotlin/com/example/mobile/MainActivity.kt
```

E adicionar ao manifesto:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

---

## 25. Segurança no perfil

A `ProfilePage` recebeu uma seção destinada à segurança:

```text
SEGURANÇA

Bloqueio do app       ON/OFF
Biometria             ON/OFF
Alterar PIN
```

O usuário pode:

- ativar bloqueio;
- desativar;
- ativar biometria;
- desativar;
- alterar PIN.

Ao encerrar definitivamente a conta, as configurações locais de segurança também devem ser removidas.

---

## 26. Identidade visual

A finalização também consolidou a identidade do produto.

Assets principais:

```text
assets/images/route_cash_logo.png
assets/images/route_cash_icon.png
```

### Login

A tela foi redesenhada com:

- card central;
- logo;
- gradiente;
- hierarquia visual;
- campos mais organizados;
- botão de cadastro;
- indicação de disponibilidade offline após primeiro acesso.

### Splash Flutter

O `AuthGate` exibe:

- gradiente;
- logo;
- carregamento;
- texto `Preparando seus dados...`.

### Home

A Home recebeu logo no cabeçalho junto da saudação e da data.

A opção final evitou colocar um fundo verde adicional atrás da logo, mantendo o visual original da marca.

---

## 27. Nome e ícone Android

No `AndroidManifest.xml`:

```xml
android:label="Route Cash"
```

faz o nome exibido no aparelho ser:

```text
Route Cash
```

O ícone foi criado com base na marca, utilizando elementos de:

- localização;
- rota;
- carro;
- crescimento financeiro;
- verde;
- fundo escuro.

Configuração:

```yaml
flutter_launcher_icons:
  android: true
  ios: false

  image_path: "assets/images/route_cash_icon.png"

  adaptive_icon_background: "#001A0F"
  adaptive_icon_foreground: "assets/images/route_cash_icon.png"
```

Geração:

```powershell
dart run flutter_launcher_icons
```

---

## 28. Problema ADB durante a finalização

Foi encontrado:

```text
INSTALL_FAILED_VERIFICATION_FAILURE
Package Verification Result
```

O erro ocorreu durante instalação via ADB no aparelho Samsung.

Não era um erro de compilação do Flutter.

O bloqueio estava relacionado à verificação de aplicativos no dispositivo/Play Protect.

Depois do ajuste temporário das verificações de instalação, o APK voltou a instalar normalmente.

Esse registro é importante para evitar investigação futura no código caso o mesmo erro apareça.

---

## 29. Arquivos alterados e criados na finalização

### Alterados

```text
lib/core/storage/secure_storage.dart
lib/features/auth/presentation/auth_gate.dart
lib/features/auth/presentation/login_page.dart
lib/features/home/presentation/home_page.dart
lib/features/users/presentation/profile_page.dart
pubspec.yaml
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/example/mobile/MainActivity.kt
```

### Criados

```text
lib/core/security/app_lock_service.dart
lib/features/auth/presentation/app_lock_page.dart
lib/features/auth/presentation/setup_pin_page.dart
assets/images/route_cash_icon.png
```

### Assets já utilizados

```text
assets/images/route_cash_logo.png
assets/platforms/
```

---

## 30. Outros arquivos centrais da arquitetura mobile

A conclusão do mobile também depende dos componentes desenvolvidos anteriormente:

```text
app_database.dart
sync_repository.dart
sync_manager.dart
sync_local_repository.dart
sync_providers.dart
vehicle_repository.dart
platform_repository.dart
earning_repository.dart
expense_repository.dart
journey_repository.dart
user_repository.dart
dio_client.dart
```

Esses arquivos formam a base de persistência, API e sincronização.

---

## 31. Dependências consolidadas

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  dio: ^5.11.1
  flutter_riverpod: ^3.3.2
  sqflite: ^2.4.2
  path: ^1.9.1
  connectivity_plus: ^7.3.1
  flutter_secure_storage: ^10.3.4
  uuid: ^4.6.0
  local_auth: ^3.0.1
  crypto: ^3.0.8
```

Desenvolvimento:

```yaml
flutter_launcher_icons: ^0.14.4
```

---

## 32. Configuração local de desenvolvimento

O backend local é acessado através de:

```text
http://127.0.0.1:3000
```

No Android físico:

```powershell
adb reverse tcp:3000 tcp:3000
```

O `AndroidManifest.xml` mantém:

```xml
android:usesCleartextTraffic="true"
```

para permitir HTTP no ambiente de desenvolvimento atual.

---

## 33. Testes já validados durante o desenvolvimento

Já foram considerados funcionais:

- login;
- cadastro;
- persistência de sessão;
- reabertura offline;
- ganhos;
- edição de ganho;
- duplicação;
- exclusão;
- despesas;
- observações;
- jornadas;
- jornada offline;
- km rodados;
- outbox;
- envio de pendências;
- snapshot;
- reconciliação;
- AutoSync;
- ausência de duplicidade;
- veículos offline;
- edição de veículo;
- veículo principal;
- placa duplicada;
- plataformas offline;
- plataforma inativa;
- indicadores;
- Home baseada em SQLite;
- logo;
- splash;
- nome do app;
- ícone.

---

## 34. Último teste recomendado para PIN/biometria

A camada de segurança local foi implementada na finalização e merece uma última validação prática completa no aparelho.

Ordem recomendada:

1. entrar no app;
2. abrir Perfil;
3. ativar Bloqueio do app;
4. criar PIN;
5. bloquear manualmente;
6. desbloquear por PIN;
7. ativar biometria;
8. bloquear novamente;
9. desbloquear por digital;
10. fechar completamente o app;
11. desligar internet;
12. abrir novamente;
13. confirmar que abre a tela bloqueada;
14. desbloquear offline;
15. usar Sair da conta;
16. tentar entrar offline;
17. confirmar que login normal não é aceito sem backend.

Esse teste diferencia corretamente segurança local de autenticação remota.

---

## 35. Comandos finais de validação

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run
```

Ícone:

```powershell
dart run flutter_launcher_icons
```

ADB:

```powershell
adb devices
adb reverse tcp:3000 tcp:3000
```

---

## 36. Funcionalidades propositalmente online

Mesmo com arquitetura local-first, algumas ações continuam dependendo de internet:

- primeiro login;
- novo login após logout;
- encerramento definitivo de conta;
- recuperação de senha;
- recursos futuros de plano/assinatura/pagamento;
- alterações estritamente dependentes da API.

Isso é intencional.

---

## 37. Itens futuros e não bloqueantes

Não são necessários para considerar o mobile atual concluído:

- recuperação completa de senha;
- metas personalizadas;
- assinatura;
- pagamento;
- planos;
- notificações avançadas;
- splash nativo Android;
- bloqueio automático por tempo;
- recursos administrativos;
- exportação PDF mobile, se desejada futuramente.

Esses pontos são evolução de produto, não correção da base atual.

---

## 38. Principais decisões técnicas da finalização

1. Não armazenar a senha normal para login offline.
2. Persistir token e userId enquanto não houver logout.
3. Manter um SQLite por usuário.
4. Separar **Bloquear app** de **Sair**.
5. Usar PIN local com hash e salt.
6. Usar biometria como complemento.
7. Permitir abertura offline de uma sessão já autenticada.
8. Salvar operações primeiro no SQLite.
9. Utilizar UUID local.
10. Reconciliar snapshot sem destruir pendências.
11. Calcular indicadores no próprio dispositivo.
12. Tornar veículos e plataformas local-first.
13. Utilizar cache do perfil.
14. Padronizar nome, logo, splash e ícone.
15. Manter o backend como fonte central sem tornar a interface dependente de internet constante.

---

## 39. Status final por área

| Área | Status |
|---|---|
| Login online | Concluído |
| Sessão persistente | Concluído e validado |
| Abertura offline | Concluído e validado |
| SQLite por usuário | Concluído |
| Ganhos local-first | Concluído |
| Despesas local-first | Concluído |
| Jornadas local-first | Concluído |
| KM rodados | Concluído |
| Indicadores | Concluído |
| Veículos local-first | Concluído e validado |
| Plataformas local-first | Concluído e validado |
| RF11 / sincronização | Concluído e validado |
| Snapshot/reconciliação | Concluído |
| AutoSync | Concluído |
| Cache de perfil | Implementado |
| Login redesenhado | Concluído |
| Splash Flutter | Concluído |
| Logo Home | Concluído |
| Nome Route Cash | Concluído |
| Ícone Android | Concluído |
| PIN local | Implementado |
| Biometria | Implementada |
| Bloquear × Sair | Implementado |
| Teste final PIN/biometria | Recomendado |
| Recuperação de senha | Futuro |
| Metas | Futuro |
| Assinaturas/pagamentos | Fase futura |

---

## 40. Estrutura resumida final

```text
mobile/
├── android/
│   └── app/
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── kotlin/com/example/mobile/MainActivity.kt
│
├── assets/
│   ├── platforms/
│   └── images/
│       ├── route_cash_logo.png
│       └── route_cash_icon.png
│
├── lib/
│   ├── core/
│   │   ├── database/app_database.dart
│   │   ├── security/app_lock_service.dart
│   │   ├── storage/secure_storage.dart
│   │   ├── theme/app_theme.dart
│   │   └── widgets/
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   └── presentation/
│   │   │       ├── auth_gate.dart
│   │   │       ├── login_page.dart
│   │   │       ├── app_lock_page.dart
│   │   │       └── setup_pin_page.dart
│   │   ├── earnings/
│   │   ├── expenses/
│   │   ├── journeys/
│   │   ├── platforms/
│   │   ├── sync/
│   │   ├── users/
│   │   └── vehicles/
│   │
│   └── main.dart
│
└── pubspec.yaml
```

---

## 41. Conclusão

A etapa mobile do Route Cash atingiu um estado sólido para o escopo acadêmico atual.

O aplicativo deixou de ser apenas uma interface conectada à API e passou a operar como uma solução local-first de fato.

O motorista consegue:

```text
registrar ganhos
registrar despesas
controlar jornadas
informar km
acompanhar indicadores
continuar trabalhando offline
sincronizar posteriormente
manter a sessão
proteger o acesso local
```

Ao mesmo tempo, o aplicativo mantém separação clara entre:

```text
sessão remota
persistência local
sincronização
bloqueio local
logout
```

A finalização visual com logo, splash, nome e ícone também deixa o projeto com identidade própria e apresentação mais profissional.

Considerando o escopo atual, o desenvolvimento futuro do mobile passa a ser majoritariamente **evolução de produto**, e não reconstrução da arquitetura principal.

O único item recomendado antes de declarar encerramento absoluto é a execução do teste completo do novo fluxo de **PIN + biometria** no aparelho físico. Com essa validação concluída, a parte mobile pode ser tratada como encerrada para a fase atual do Route Cash.

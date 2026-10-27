class DatabaseTables {
  DatabaseTables._();

  static const String ganhosLocal = 'ganhos_local';
  static const String despesasLocal = 'despesas_local';
  static const String jornadasLocal = 'jornadas_local';

  static const String veiculosCache = 'veiculos_cache';
  static const String plataformasCache = 'plataformas_cache';
  static const String categoriasCache = 'categorias_cache';

  static const String syncOutbox = 'sync_outbox';

  static const List<String> createStatements = [
    '''
    CREATE TABLE $ganhosLocal (
      id_ganho TEXT PRIMARY KEY,
      id_veiculo TEXT NOT NULL,
      id_plataforma TEXT NOT NULL,
      valor REAL NOT NULL,
      data TEXT NOT NULL,
      observacao TEXT,
      atualizado_em TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $despesasLocal (
      id_despesa TEXT PRIMARY KEY,
      id_veiculo TEXT NOT NULL,
      id_categoria TEXT NOT NULL,
      valor REAL NOT NULL,
      data TEXT NOT NULL,
      observacao TEXT,
      atualizado_em TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $jornadasLocal (
      id_jornada TEXT PRIMARY KEY,
      id_veiculo TEXT NOT NULL,
      inicio TEXT NOT NULL,
      fim TEXT,
      km_rodados REAL,
      atualizado_em TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $veiculosCache (
      id_veiculo TEXT PRIMARY KEY,
      marca TEXT NOT NULL,
      modelo TEXT NOT NULL,
      placa TEXT,
      ativo INTEGER NOT NULL DEFAULT 1,
      principal INTEGER NOT NULL DEFAULT 0,
      raw_json TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $plataformasCache (
      id_plataforma TEXT PRIMARY KEY,
      nome TEXT NOT NULL,
      ativa INTEGER NOT NULL DEFAULT 1,
      padrao INTEGER NOT NULL DEFAULT 0,
      raw_json TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $categoriasCache (
      id_categoria TEXT PRIMARY KEY,
      nome TEXT NOT NULL,
      raw_json TEXT NOT NULL
    )
    ''',

    '''
    CREATE TABLE $syncOutbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entidade TEXT NOT NULL,
      registro_id TEXT NOT NULL,
      operacao TEXT NOT NULL,
      payload_json TEXT,
      estado TEXT NOT NULL DEFAULT 'pendente',
      codigo_erro TEXT,
      motivo_erro TEXT,
      tentativas INTEGER NOT NULL DEFAULT 0,
      atualizado_em TEXT NOT NULL,
      UNIQUE(entidade, registro_id)
    )
    ''',

    '''
    CREATE INDEX idx_sync_outbox_estado
    ON $syncOutbox (estado, atualizado_em)
    ''',

    '''
    CREATE INDEX idx_ganhos_data
    ON $ganhosLocal (data)
    ''',

    '''
    CREATE INDEX idx_despesas_data
    ON $despesasLocal (data)
    ''',

    '''
    CREATE INDEX idx_jornadas_inicio
    ON $jornadasLocal (inicio)
    ''',
  ];
}

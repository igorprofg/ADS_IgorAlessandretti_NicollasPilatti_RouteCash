import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/platform_icon.dart';

import '../../auth/presentation/login_page.dart';

import '../../earnings/data/earning.dart';
import '../../earnings/presentation/earning_form_page.dart';
import '../../earnings/presentation/earning_list_page.dart';
import '../../earnings/providers/earning_providers.dart';

import '../../expenses/data/expense.dart';
import '../../expenses/presentation/expense_form_page.dart';
import '../../expenses/presentation/expense_list_page.dart';
import '../../expenses/providers/expense_providers.dart';

import '../../platforms/presentation/platform_list_page.dart';

import '../../users/presentation/profile_page.dart';
import '../../users/providers/user_providers.dart';

import '../../vehicles/presentation/vehicle_list_page.dart';

import '../../journeys/data/journey.dart';
import '../../journeys/presentation/journey_page.dart';
import '../../journeys/providers/journey_providers.dart';

import '../../sync/providers/sync_providers.dart';

enum _PeriodType { day, week, month, year }

enum _ActivityFilter { all, earnings, expenses }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, dynamic>? _usuario;

  List<Earning> _earnings = [];
  List<Expense> _expenses = [];
  List<Journey> _journeys = [];

  StreamSubscription<void>? _syncSubscription;

  bool _carregando = true;
  String? _erro;

  _PeriodType _periodoSelecionado = _PeriodType.day;

  DateTime _dataReferencia = DateTime.now();

  _ActivityFilter _filtroAtividade = _ActivityFilter.all;

  bool _mostrarTodasAtividades = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final autoSync = ref.read(syncAutoServiceProvider);

      autoSync.start();

      _syncSubscription = autoSync.onSynced.listen((_) async {
        if (!mounted) {
          return;
        }

        await _recarregarDashboardLocal();
      });

      await _carregarDashboard();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _carregarDashboard() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    await _recarregarDashboardLocal();

    try {
      final userRepository = ref.read(userRepositoryProvider);

      final usuario = await userRepository.getMyProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _usuario = usuario;
      });
    } catch (e) {
      debugPrint('Perfil não pôde ser atualizado agora: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _carregando = false;
      _erro = null;
    });
  }

  Future<void> _recarregarDashboardLocal() async {
    try {
      final earningRepository = ref.read(earningRepositoryProvider);

      final expenseRepository = ref.read(expenseRepositoryProvider);

      final journeyRepository = ref.read(journeyRepositoryProvider);

      final earnings = await earningRepository.findAll();
      final expenses = await expenseRepository.findAll();

      var journeys = _journeys;

      try {
        journeys = await journeyRepository.findAll();
      } catch (e) {
        debugPrint('Erro ao carregar jornadas locais: $e');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _earnings = earnings;
        _expenses = expenses;
        _journeys = journeys;

        _erro = null;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao recarregar dashboard local: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _carregando = false;
        _erro = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  bool _mesmoDia(DateTime a, DateTime b) {
    final dataA = _somenteData(a);

    final dataB = _somenteData(b);

    return dataA.year == dataB.year &&
        dataA.month == dataB.month &&
        dataA.day == dataB.day;
  }

  bool _estaNoPeriodo(DateTime data) {
    final registro = _somenteData(data);

    final referencia = _somenteData(_dataReferencia);

    switch (_periodoSelecionado) {
      case _PeriodType.day:
        return _mesmoDia(registro, referencia);

      case _PeriodType.week:
        final inicioSemana = referencia.subtract(
          Duration(days: referencia.weekday - 1),
        );

        final fimSemana = inicioSemana.add(const Duration(days: 7));

        return !registro.isBefore(inicioSemana) && registro.isBefore(fimSemana);

      case _PeriodType.month:
        return registro.year == referencia.year &&
            registro.month == referencia.month;

      case _PeriodType.year:
        return registro.year == referencia.year;
    }
  }

  List<Earning> get _ganhosPeriodo {
    return _earnings.where((earning) => _estaNoPeriodo(earning.data)).toList();
  }

  List<Expense> get _despesasPeriodo {
    return _expenses.where((expense) => _estaNoPeriodo(expense.data)).toList();
  }

  List<Journey> get _jornadasPeriodo {
    return _journeys
        .where((journey) => _estaNoPeriodo(journey.inicio))
        .toList();
  }

  double get _totalHorasTrabalhadas {
    var minutos = 0;

    for (final journey in _jornadasPeriodo) {
      if (journey.fim == null) {
        continue;
      }

      minutos += journey.fim!.difference(journey.inicio).inMinutes;
    }

    return minutos / 60.0;
  }

  double get _totalKmRodados {
    return _jornadasPeriodo.fold(
      0.0,
      (total, journey) => total + (journey.kmRodados ?? 0),
    );
  }

  double get _ganhoPorHora {
    if (_totalHorasTrabalhadas <= 0) {
      return 0;
    }

    return _lucro / _totalHorasTrabalhadas;
  }

  double get _ganhoPorKm {
    if (_totalKmRodados <= 0) {
      return 0;
    }

    return _lucro / _totalKmRodados;
  }

  double get _custoPorKm {
    if (_totalKmRodados <= 0) {
      return 0;
    }

    return _totalDespesas / _totalKmRodados;
  }

  double get _totalGanhos {
    return _ganhosPeriodo.fold(0, (total, earning) => total + earning.valor);
  }

  double get _totalDespesas {
    return _despesasPeriodo.fold(0, (total, expense) => total + expense.valor);
  }

  double get _lucro {
    return _totalGanhos - _totalDespesas;
  }

  String get _primeiroNome {
    final nome = _usuario?['nome']?.toString().trim();

    if (nome == null || nome.isEmpty) {
      return 'Motorista';
    }

    return nome.split(' ').first;
  }

  List<_ActivityItem> get _todasAtividadesPeriodo {
    final ganhos = <_ActivityItem>[];

    final despesas = <_ActivityItem>[];

    for (final earning in _ganhosPeriodo) {
      ganhos.add(
        _ActivityItem(
          data: earning.data,
          titulo: 'Ganho',
          subtitulo:
              '${earning.veiculoMarca ?? ''} '
                      '${earning.veiculoModelo ?? ''}'
                  .trim(),
          valor: earning.valor,
          entrada: true,
          plataformaNome: earning.plataformaNome,
        ),
      );
    }

    for (final expense in _despesasPeriodo) {
      despesas.add(
        _ActivityItem(
          data: expense.data,
          titulo: expense.categoriaNome ?? 'Despesa',
          subtitulo:
              '${expense.veiculoMarca ?? ''} '
                      '${expense.veiculoModelo ?? ''}'
                  .trim(),
          valor: expense.valor,
          entrada: false,
          plataformaNome: null,
        ),
      );
    }

    final datas = <DateTime>{};

    for (final ganho in ganhos) {
      datas.add(_somenteData(ganho.data));
    }

    for (final despesa in despesas) {
      datas.add(_somenteData(despesa.data));
    }

    final datasOrdenadas = datas.toList()..sort((a, b) => b.compareTo(a));

    final atividades = <_ActivityItem>[];

    for (final data in datasOrdenadas) {
      final ganhosDoDia = ganhos
          .where((item) => _mesmoDia(item.data, data))
          .toList();

      final despesasDoDia = despesas
          .where((item) => _mesmoDia(item.data, data))
          .toList();

      var indiceGanho = 0;
      var indiceDespesa = 0;

      while (indiceGanho < ganhosDoDia.length ||
          indiceDespesa < despesasDoDia.length) {
        if (indiceGanho < ganhosDoDia.length) {
          atividades.add(ganhosDoDia[indiceGanho]);

          indiceGanho++;
        }

        if (indiceDespesa < despesasDoDia.length) {
          atividades.add(despesasDoDia[indiceDespesa]);

          indiceDespesa++;
        }
      }
    }

    return atividades;
  }

  List<_ActivityItem> get _atividadesFiltradas {
    switch (_filtroAtividade) {
      case _ActivityFilter.all:
        return _todasAtividadesPeriodo;

      case _ActivityFilter.earnings:
        return _todasAtividadesPeriodo
            .where((atividade) => atividade.entrada)
            .toList();

      case _ActivityFilter.expenses:
        return _todasAtividadesPeriodo
            .where((atividade) => !atividade.entrada)
            .toList();
    }
  }

  List<_ActivityItem> get _atividadesVisiveis {
    final atividades = _atividadesFiltradas;

    if (_mostrarTodasAtividades || atividades.length <= 5) {
      return atividades;
    }

    return atividades.take(5).toList();
  }

  void _alterarFiltroAtividade(_ActivityFilter filtro) {
    setState(() {
      _filtroAtividade = filtro;
      _mostrarTodasAtividades = false;
    });
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();

    final selecionada = await showDatePicker(
      context: context,
      initialDate: _dataReferencia.isAfter(agora) ? agora : _dataReferencia,
      firstDate: DateTime(2020),
      lastDate: agora,
      helpText: 'Selecionar período',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (selecionada == null) {
      return;
    }

    setState(() {
      _dataReferencia = selecionada;

      _mostrarTodasAtividades = false;
    });
  }

  void _alterarPeriodo(_PeriodType periodo) {
    setState(() {
      _periodoSelecionado = periodo;

      _filtroAtividade = _ActivityFilter.all;

      _mostrarTodasAtividades = false;
    });
  }

  void _periodoAnterior() {
    setState(() {
      switch (_periodoSelecionado) {
        case _PeriodType.day:
          _dataReferencia = _dataReferencia.subtract(const Duration(days: 1));
          break;

        case _PeriodType.week:
          _dataReferencia = _dataReferencia.subtract(const Duration(days: 7));
          break;

        case _PeriodType.month:
          _dataReferencia = DateTime(
            _dataReferencia.year,
            _dataReferencia.month - 1,
            1,
          );
          break;

        case _PeriodType.year:
          _dataReferencia = DateTime(_dataReferencia.year - 1, 1, 1);
          break;
      }

      _mostrarTodasAtividades = false;
    });
  }

  void _proximoPeriodo() {
    final hoje = _somenteData(DateTime.now());

    DateTime novaData;

    switch (_periodoSelecionado) {
      case _PeriodType.day:
        novaData = _dataReferencia.add(const Duration(days: 1));
        break;

      case _PeriodType.week:
        novaData = _dataReferencia.add(const Duration(days: 7));
        break;

      case _PeriodType.month:
        novaData = DateTime(_dataReferencia.year, _dataReferencia.month + 1, 1);
        break;

      case _PeriodType.year:
        novaData = DateTime(_dataReferencia.year + 1, 1, 1);
        break;
    }

    if (_somenteData(novaData).isAfter(hoje)) {
      return;
    }

    setState(() {
      _dataReferencia = novaData;

      _mostrarTodasAtividades = false;
    });
  }

  void _voltarParaHoje() {
    setState(() {
      _dataReferencia = DateTime.now();

      _mostrarTodasAtividades = false;
    });
  }

  String _nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return meses[mes - 1];
  }

  String _nomeMesCurto(int mes) {
    const meses = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    return meses[mes - 1];
  }

  String get _textoPeriodo {
    final referencia = _somenteData(_dataReferencia);

    switch (_periodoSelecionado) {
      case _PeriodType.day:
        return '${referencia.day} de '
            '${_nomeMes(referencia.month).toLowerCase()} '
            'de ${referencia.year}';

      case _PeriodType.week:
        final inicio = referencia.subtract(
          Duration(days: referencia.weekday - 1),
        );

        final fim = inicio.add(const Duration(days: 6));

        if (inicio.month == fim.month && inicio.year == fim.year) {
          return '${inicio.day} a '
              '${fim.day} de '
              '${_nomeMesCurto(inicio.month)} '
              '${inicio.year}';
        }

        if (inicio.year == fim.year) {
          return '${inicio.day} '
              '${_nomeMesCurto(inicio.month)} '
              'a ${fim.day} '
              '${_nomeMesCurto(fim.month)} '
              '${fim.year}';
        }

        return '${inicio.day} '
            '${_nomeMesCurto(inicio.month)} '
            '${inicio.year} a '
            '${fim.day} '
            '${_nomeMesCurto(fim.month)} '
            '${fim.year}';

      case _PeriodType.month:
        return '${_nomeMes(referencia.month)} '
            'de ${referencia.year}';

      case _PeriodType.year:
        return referencia.year.toString();
    }
  }

  String get _tituloPeriodo {
    switch (_periodoSelecionado) {
      case _PeriodType.day:
        return 'Resumo do dia';

      case _PeriodType.week:
        return 'Resumo da semana';

      case _PeriodType.month:
        return 'Resumo do mês';

      case _PeriodType.year:
        return 'Resumo do ano';
    }
  }

  Future<void> _abrirPerfil() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );

    if (atualizado == true) {
      await _carregarDashboard();
    }
  }

  Future<void> _abrirVeiculos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VehicleListPage()),
    );
  }

  Future<void> _abrirPlataformas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlatformListPage()),
    );
  }

  Future<void> _abrirGanhos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EarningListPage()),
    );

    await _recarregarDashboardLocal();
  }

  Future<void> _abrirDespesas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpenseListPage()),
    );

    await _recarregarDashboardLocal();
  }

  Future<void> _abrirJornadas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JourneyPage()),
    );

    await _recarregarDashboardLocal();
  }

  Future<void> _registrarGanho() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EarningFormPage()),
    );

    if (atualizado == true) {
      await _recarregarDashboardLocal();
    }
  }

  Future<void> _registrarDespesa() async {
    final atualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ExpenseFormPage()),
    );

    if (atualizado == true) {
      await _recarregarDashboardLocal();
    }
  }

  Future<void> _sair() async {
    await SecureStorage.deleteToken();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _selecionarMenu(String value) {
    switch (value) {
      case 'perfil':
        _abrirPerfil();
        break;

      case 'veiculos':
        _abrirVeiculos();
        break;

      case 'plataformas':
        _abrirPlataformas();
        break;

      case 'ganhos':
        _abrirGanhos();
        break;

      case 'despesas':
        _abrirDespesas();
        break;

      case 'jornadas':
        _abrirJornadas();
        break;

      case 'sair':
        _sair();
        break;
    }
  }

  String _formatarMoeda(double valor) {
    final negativo = valor < 0;

    final absoluto = valor.abs();

    final partes = absoluto.toStringAsFixed(2).split('.');

    final inteiro = partes[0];
    final decimal = partes[1];

    final buffer = StringBuffer();

    for (var i = 0; i < inteiro.length; i++) {
      final restante = inteiro.length - i;

      buffer.write(inteiro[i]);

      if (restante > 1 && restante % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${negativo ? '-' : ''}'
        'R\$ ${buffer.toString()},$decimal';
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');

    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  String get _dataCabecalho {
    const dias = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];

    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    final agora = DateTime.now();

    return '${dias[agora.weekday - 1]}, '
        '${agora.day} de '
        '${meses[agora.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Olá, $_primeiroNome',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 2),

            Text(
              _dataCabecalho,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: _selecionarMenu,
            icon: const CircleAvatar(
              radius: 19,
              child: Icon(Icons.person_outline, size: 21),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'perfil',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Meu perfil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ganhos',
                child: Row(
                  children: [
                    Icon(Icons.trending_up),
                    SizedBox(width: 12),
                    Text('Ganhos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'despesas',
                child: Row(
                  children: [
                    Icon(Icons.trending_down),
                    SizedBox(width: 12),
                    Text('Despesas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'jornadas',
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined),
                    SizedBox(width: 12),
                    Text('Jornadas'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'veiculos',
                child: Row(
                  children: [
                    Icon(Icons.directions_car_outlined),
                    SizedBox(width: 12),
                    Text('Meus veículos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'plataformas',
                child: Row(
                  children: [
                    Icon(Icons.phone_android_outlined),
                    SizedBox(width: 12),
                    Text('Plataformas'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? _buildErro()
          : RefreshIndicator(
              onRefresh: () async {
                final autoSync = ref.read(syncAutoServiceProvider);

                await autoSync.tryNow(forceFullSync: true);

                await _recarregarDashboardLocal();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResumo(),

                    const SizedBox(height: 14),

                    _buildIndicadoresLocais(),

                    const SizedBox(height: 18),

                    _buildAcoesRapidas(),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Atividades do período',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_todasAtividadesPeriodo.length} '
                          '${_todasAtividadesPeriodo.length == 1 ? 'lançamento' : 'lançamentos'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildFiltrosAtividade(),

                    const SizedBox(height: 12),

                    _buildAtividades(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResumo() {
    final lucroPositivo = _lucro >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primaryBright],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 18,
                ),

                const SizedBox(width: 7),

                Text(
                  _tituloPeriodo.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE7FFF0),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildFiltrosPeriodo(),

            const SizedBox(height: 14),

            _buildNavegacaoPeriodo(),

            const SizedBox(height: 20),

            const Text(
              'Lucro líquido',
              style: TextStyle(
                color: Color(0xFFDDF5E6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              _formatarMoeda(_lucro),
              style: TextStyle(
                color: lucroPositivo ? Colors.white : const Color(0xFFFFE1E1),
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      icon: Icons.arrow_upward,
                      label: 'Ganhos',
                      value: _formatarMoeda(_totalGanhos),
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.20),
                  ),

                  Expanded(
                    child: _SummaryValue(
                      icon: Icons.arrow_downward,
                      label: 'Despesas',
                      value: _formatarMoeda(_totalDespesas),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadoresLocais() {
    String horasTexto() {
      if (_totalHorasTrabalhadas <= 0) {
        return '0h';
      }

      final horas = _totalHorasTrabalhadas.floor();

      final minutos = ((_totalHorasTrabalhadas - horas) * 60).round();

      return '${horas}h '
          '${minutos.toString().padLeft(2, '0')}min';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indicadores do período',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _LocalIndicator(
                    icon: Icons.schedule_outlined,
                    label: 'Horas',
                    value: horasTexto(),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _LocalIndicator(
                    icon: Icons.route_outlined,
                    label: 'Quilômetros',
                    value: '${_totalKmRodados.toStringAsFixed(1)} km',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _LocalIndicator(
                    icon: Icons.payments_outlined,
                    label: 'Ganho/hora',
                    value: _formatarMoeda(_ganhoPorHora),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _LocalIndicator(
                    icon: Icons.trending_up_outlined,
                    label: 'Ganho/km',
                    value: _formatarMoeda(_ganhoPorKm),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _LocalIndicator(
              icon: Icons.speed_outlined,
              label: 'Custo/km',
              value: _formatarMoeda(_custoPorKm),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosPeriodo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodButton(
              label: 'Dia',
              selected: _periodoSelecionado == _PeriodType.day,
              onTap: () => _alterarPeriodo(_PeriodType.day),
            ),
          ),
          Expanded(
            child: _PeriodButton(
              label: 'Semana',
              selected: _periodoSelecionado == _PeriodType.week,
              onTap: () => _alterarPeriodo(_PeriodType.week),
            ),
          ),
          Expanded(
            child: _PeriodButton(
              label: 'Mês',
              selected: _periodoSelecionado == _PeriodType.month,
              onTap: () => _alterarPeriodo(_PeriodType.month),
            ),
          ),
          Expanded(
            child: _PeriodButton(
              label: 'Ano',
              selected: _periodoSelecionado == _PeriodType.year,
              onTap: () => _alterarPeriodo(_PeriodType.year),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavegacaoPeriodo() {
    return Row(
      children: [
        _PeriodArrowButton(icon: Icons.chevron_left, onTap: _periodoAnterior),

        const SizedBox(width: 6),

        Expanded(
          child: InkWell(
            onTap: _selecionarData,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white,
                    size: 18,
                  ),

                  const SizedBox(width: 7),

                  Flexible(
                    child: Text(
                      _textoPeriodo,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        _PeriodArrowButton(icon: Icons.chevron_right, onTap: _proximoPeriodo),

        const SizedBox(width: 4),

        IconButton(
          onPressed: _voltarParaHoje,
          tooltip: 'Voltar para hoje',
          icon: const Icon(Icons.today_outlined, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  Widget _buildAcoesRapidas() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add,
            label: 'Registrar ganho',
            color: AppTheme.income,
            onTap: _registrarGanho,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _QuickActionButton(
            icon: Icons.remove,
            label: 'Registrar despesa',
            color: AppTheme.expense,
            onTap: _registrarDespesa,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltrosAtividade() {
    return Row(
      children: [
        Expanded(
          child: _ActivityFilterButton(
            label: 'Todos',
            count: _todasAtividadesPeriodo.length,
            selected: _filtroAtividade == _ActivityFilter.all,
            onTap: () => _alterarFiltroAtividade(_ActivityFilter.all),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _ActivityFilterButton(
            label: 'Ganhos',
            count: _ganhosPeriodo.length,
            selected: _filtroAtividade == _ActivityFilter.earnings,
            onTap: () => _alterarFiltroAtividade(_ActivityFilter.earnings),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: _ActivityFilterButton(
            label: 'Despesas',
            count: _despesasPeriodo.length,
            selected: _filtroAtividade == _ActivityFilter.expenses,
            onTap: () => _alterarFiltroAtividade(_ActivityFilter.expenses),
          ),
        ),
      ],
    );
  }

  Widget _buildAtividades() {
    final atividades = _atividadesVisiveis;

    if (atividades.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),

                const SizedBox(height: 12),

                Text(
                  _filtroAtividade == _ActivityFilter.earnings
                      ? 'Nenhum ganho neste período'
                      : _filtroAtividade == _ActivityFilter.expenses
                      ? 'Nenhuma despesa neste período'
                      : 'Nenhuma atividade neste período',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Os lançamentos do período selecionado aparecerão aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: atividades.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 68),
            itemBuilder: (context, index) {
              final item = atividades[index];

              final cor = item.entrada ? AppTheme.income : AppTheme.expense;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: item.entrada && item.plataformaNome != null
                    ? PlatformIcon(platformName: item.plataformaNome!, size: 42)
                    : Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.arrow_downward, color: cor, size: 20),
                      ),
                title: Text(
                  item.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  item.subtitulo.isEmpty
                      ? _formatarData(item.data)
                      : '${item.subtitulo} • '
                            '${_formatarData(item.data)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  '${item.entrada ? '+' : '-'}'
                  '${_formatarMoeda(item.valor)}',
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),

          if (_atividadesFiltradas.length > 5)
            Column(
              children: [
                const Divider(height: 1),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _mostrarTodasAtividades = !_mostrarTodasAtividades;
                    });
                  },
                  icon: Icon(
                    _mostrarTodasAtividades
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    _mostrarTodasAtividades
                        ? 'Mostrar menos'
                        : 'Mostrar todas (${_atividadesFiltradas.length})',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),

            const SizedBox(height: 16),

            Text(_erro!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _carregarDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppTheme.primaryDark : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PeriodArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _ActivityFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                ),
              ),

              const SizedBox(width: 5),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),

              const SizedBox(width: 5),

              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFDDF5E6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 21),

              const SizedBox(width: 7),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _LocalIndicator({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final DateTime data;
  final String titulo;
  final String subtitulo;
  final double valor;
  final bool entrada;
  final String? plataformaNome;

  const _ActivityItem({
    required this.data,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.entrada,
    this.plataformaNome,
  });
}

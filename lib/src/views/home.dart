import 'package:spoton/src/views/auth.dart';
import 'package:spoton/src/views/account.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spoton/src/models/event.dart';
import 'package:spoton/src/services/event_service.dart';
import 'package:spoton/src/views/settings.dart';
import 'package:spoton/src/views/widgets/colors.dart';
import 'package:spoton/src/views/widgets/event_card.dart';

final _eventDateFormat = DateFormat('dd/MM/yyyy • HH:mm');
String eventDate(DateTime date) => _eventDateFormat.format(date);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int tab = 0;
  String query = '';
  EventCategory? category;
  bool favorites = false;
  bool freeOnly = false;
  double? maxPrice;
  DateTimeRange? dates;
  EventSort sort = EventSort.date;
  final searchController = TextEditingController();
  Timer? searchDebounce;

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDateRange: dates,
    );
    if (mounted && selected != null) setState(() => dates = selected);
  }

  void quickDates(bool weekend) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final offset = today.weekday == DateTime.sunday
        ? 0
        : (DateTime.saturday - today.weekday + 7) % 7;
    final start = weekend ? today.add(Duration(days: offset)) : today;
    final end = weekend && start.weekday == DateTime.saturday
        ? start.add(const Duration(days: 1))
        : start;
    setState(() => dates = DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EventService>();
    final events = service.searchEvents(
      query,
      category: category,
      favoritesOnly: favorites,
      freeOnly: freeOnly,
      maxPrice: maxPrice,
      upcomingOnly: true,
      from: dates?.start,
      until: dates == null
          ? null
          : DateTime(dates!.end.year, dates!.end.month, dates!.end.day + 1),
      sort: sort,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar_rounded, color: AppColors.accent, size: 32),
            SizedBox(width: 10),
            Text(
              'spoton',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: service.isSignedIn
                ? 'Minha conta'
                : 'Entrar ou criar conta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    service.isSignedIn ? const AccountPage() : const AuthPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: SafeArea(child: SettingsPage())),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (service.syncError != null)
            MaterialBanner(
              content: Text(service.syncError!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: SafeArea(child: SettingsPage())),
                    ),
                  ),
                  child: const Text('Configurações'),
                ),
              ],
            ),
          if (service.isCloudEnabled && !service.isSignedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Entre para publicar eventos e sincronizar ingressos.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                    ),
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: tab == 0
                    ? RefreshIndicator(
                        onRefresh: service.refreshEvents,
                        child: CustomScrollView(
                          key: const PageStorageKey('discovery'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(20),
                              sliver: SliverMainAxisGroup(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.brandGradient,
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'SAIA DO ÓBVIO',
                                                style: TextStyle(
                                                  letterSpacing: 3,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Seu próximo encontro\ncom algo incrível.',
                                                style: TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              const Text(
                                                'Descubra experiências ou coloque seu evento no mapa.',
                                              ),
                                              const SizedBox(height: 16),
                                              FilledButton.tonalIcon(
                                                onPressed: createEvent,
                                                icon: const Icon(Icons.add),
                                                label: const Text(
                                                  'Criar meu evento',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        TextField(
                                          key: const Key('event-search'),
                                          controller: searchController,
                                          onChanged: (value) {
                                            searchDebounce?.cancel();
                                            searchDebounce = Timer(
                                              const Duration(milliseconds: 250),
                                              () {
                                                if (mounted)
                                                  setState(() => query = value);
                                              },
                                            );
                                          },
                                          decoration: const InputDecoration(
                                            hintText: 'Buscar evento, local ou organizador',
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: FilterChip(
                                                  key: const Key(
                                                    'filter-favorites',
                                                  ),
                                                  label: const Text(
                                                    'Favoritos',
                                                  ),
                                                  selected: favorites,
                                                  onSelected: (v) => setState(
                                                    () => favorites = v,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: ChoiceChip(
                                                  label: const Text('Todos'),
                                                  selected: category == null,
                                                  onSelected: (_) => setState(
                                                    () => category = null,
                                                  ),
                                                ),
                                              ),
                                              ...EventCategory.values.map(
                                                (c) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: ChoiceChip(
                                                    key: Key(
                                                      'category-${c.name}',
                                                    ),
                                                    avatar: Icon(
                                                      c.icon,
                                                      size: 18,
                                                    ),
                                                    label: Text(c.displayName),
                                                    selected: category == c,
                                                    onSelected: (_) => setState(
                                                      () => category =
                                                          category == c
                                                          ? null
                                                          : c,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            FilterChip(
                                              key: const Key('filter-free'),
                                              label: const Text(
                                                'Somente gratuitos',
                                              ),
                                              selected: freeOnly,
                                              onSelected: (v) =>
                                                  setState(() => freeOnly = v),
                                            ),
                                            ActionChip(
                                              label: const Text('Hoje'),
                                              onPressed: () =>
                                                  quickDates(false),
                                            ),
                                            ActionChip(
                                              label: const Text(
                                                'Fim de semana',
                                              ),
                                              onPressed: () => quickDates(true),
                                            ),
                                            DropdownButton<double>(
                                              hint: const Text('Preço máximo'),
                                              value: maxPrice,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 25,
                                                  child: Text('Até R\$ 25'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 50,
                                                  child: Text('Até R\$ 50'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 100,
                                                  child: Text('Até R\$ 100'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 200,
                                                  child: Text('Até R\$ 200'),
                                                ),
                                              ],
                                              onChanged: (value) => setState(
                                                () => maxPrice = value,
                                              ),
                                            ),
                                            InputChip(
                                              avatar: const Icon(
                                                Icons.date_range,
                                                size: 18,
                                              ),
                                              label: Text(
                                                dates == null
                                                    ? 'Escolher período'
                                                    : '${DateFormat('dd/MM').format(dates!.start)} – ${DateFormat('dd/MM').format(dates!.end)}',
                                              ),
                                              onPressed: pickDates,
                                              onDeleted: dates == null
                                                  ? null
                                                  : () => setState(
                                                      () => dates = null,
                                                    ),
                                            ),
                                            DropdownButton<EventSort>(
                                              value: sort,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: EventSort.date,
                                                  child: Text('Mais próximos'),
                                                ),
                                                DropdownMenuItem(
                                                  value: EventSort.price,
                                                  child: Text('Menor preço'),
                                                ),
                                                DropdownMenuItem(
                                                  value: EventSort.name,
                                                  child: Text('Nome A–Z'),
                                                ),
                                              ],
                                              onChanged: (v) {
                                                if (v != null)
                                                  setState(() => sort = v);
                                              },
                                            ),
                                            TextButton(
                                              onPressed: () => setState(() {
                                                searchDebounce?.cancel();
                                                searchController.clear();
                                                query = '';
                                                category = null;
                                                favorites = false;
                                                freeOnly = false;
                                                maxPrice = null;
                                                dates = null;
                                                sort = EventSort.date;
                                              }),
                                              child: const Text(
                                                'Limpar filtros',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Explore novas experiências',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          service.isCloudEnabled
                                              ? 'Eventos da comunidade'
                                              : 'Eventos publicados neste dispositivo',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          '${events.length} evento(s) encontrado(s)',
                                        ),
                                        if (service.isCloudEnabled) ...[
                                          const Text(
                                            'Filtros aplicados aos eventos carregados. Carregue mais para ampliar a busca.',
                                          ),
                                          Wrap(
                                            spacing: 12,
                                            children: [
                                              TextButton.icon(
                                                onPressed: service.loadingEvents
                                                    ? null
                                                    : service.refreshEvents,
                                                icon: const Icon(Icons.refresh),
                                                label: const Text(
                                                  'Atualizar eventos',
                                                ),
                                              ),
                                              if (service.hasMoreEvents)
                                                OutlinedButton(
                                                  onPressed:
                                                      service.loadingEvents
                                                      ? null
                                                      : service.loadMoreEvents,
                                                  child: Text(
                                                    service.loadingEvents
                                                        ? 'Carregando…'
                                                        : 'Carregar mais eventos',
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (service.loadingEvents)
                                            const LinearProgressIndicator(),
                                        ],
                                        const SizedBox(height: 16),
                                        if (events.isEmpty)
                                          empty(
                                            'Nenhum evento por aqui',
                                            service.loadingEvents
                                                ? 'Buscando eventos…'
                                                : 'Ajuste os filtros, carregue mais eventos ou publique o seu.',
                                            Icons.explore_outlined,
                                          ),
                                      ],
                                    ),
                                  ),
                                  SliverList.builder(
                                    itemCount: events.length,
                                    itemBuilder: (context, index) {
                                      final e = events[index];
                                      return EventCard(
                                        key: ValueKey(e.eventID),
                                        event: e,
                                        date: eventDate(e.startAt),
                                        favorite: service.isFavorite(e.eventID),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EventDetails(event: e),
                                          ),
                                        ),
                                        onFavorite:
                                            service.favoritePending(e.eventID)
                                            ? null
                                            : () async {
                                                if (!requireAccount(context))
                                                  return;
                                                try {
                                                  await service.toggleFavorite(
                                                    e.eventID,
                                                  );
                                                } catch (_) {
                                                  if (context.mounted)
                                                    message(
                                                      context,
                                                      'Não foi possível salvar o favorito.',
                                                    );
                                                }
                                              },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : tab == 1
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Meus ingressos',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          if (service.tickets.isEmpty)
                            empty(
                              'Sua próxima experiência espera',
                              'Os ingressos gratuitos emitidos aparecem aqui.',
                              Icons.confirmation_number_outlined,
                            ),
                          ...service.tickets.map(
                            (t) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'INGRESSO GRATUITO',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      t.eventName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(eventDate(t.eventDate)),
                                    Text(t.location),
                                    const Divider(height: 28),
                                    SelectableText(
                                      t.ticketCode,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    Text(
                                      '${t.quantity} ingresso(s) • ${t.formattedTotal}',
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Cancelar ingresso?',
                                            ),
                                            content: Text(
                                              service.isCloudEnabled
                                                  ? 'O ingresso será cancelado na sua conta.'
                                                  : 'O ingresso será removido deste dispositivo.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Voltar'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text(
                                                  'Cancelar ingresso',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          try {
                                            await service.cancelTicket(t.id);
                                          } catch (_) {
                                            if (context.mounted)
                                              message(
                                                context,
                                                'Não foi possível cancelar.',
                                              );
                                          }
                                        }
                                      },
                                      child: const Text('Cancelar ingresso'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Meus eventos',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Publique uma experiência e compartilhe os detalhes com seus convidados.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: createEvent,
                            icon: const Icon(Icons.add),
                            label: const Text('Publicar evento'),
                          ),
                          ...service.myEvents.map(
                            (e) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              leading: Icon(e.categoryIcon),
                              title: Text(e.nome),
                              subtitle: Text(
                                '${eventDate(e.startAt)}\n${e.formattedPrice}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetails(event: e),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Ingressos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Meus eventos',
          ),
        ],
      ),
    );
  }

  Future<void> createEvent() async {
    if (!requireAccount(context)) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateEventPage()),
    );
    if (created == true && mounted) {
      setState(() {
        tab = 2;
      });
      message(
        context,
        context.read<EventService>().isCloudEnabled
            ? 'Evento publicado na comunidade!'
            : 'Evento publicado neste dispositivo!',
      );
    }
  }
}

bool requireAccount(BuildContext context) {
  final service = context.read<EventService>();
  if (!service.isCloudEnabled || service.isSignedIn) return true;
  message(context, 'Entre na sua conta para continuar.');
  Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  return false;
}

Widget empty(String title, String description, IconData icon) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(
    children: [
      Icon(icon, size: 54, color: AppColors.accent),
      const SizedBox(height: 16),
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(description, textAlign: TextAlign.center),
    ],
  ),
);
void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class EventDetails extends StatefulWidget {
  final Event event;
  const EventDetails({super.key, required this.event});
  @override
  State<EventDetails> createState() => _EventDetailsState();
}

class _EventDetailsState extends State<EventDetails> {
  int quantity = 1;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final expired = !e.startAt.isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua próxima experiência'),
        actions: [
          IconButton(
            tooltip: 'Copiar detalhes do evento',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              try {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '${e.nome}\n${eventDate(e.startAt)} até ${eventDate(e.endAt)}\n${e.local}\n${e.formattedPrice}\nPor ${e.organizer}\n${e.description}'
                        '${e.checkoutUrl == null ? '' : '\n${e.checkoutUrl}'}',
                  ),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Detalhes copiados.')),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Não foi possível copiar.')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(e.categoryIcon, size: 80),
              ),
              const SizedBox(height: 24),
              Text(
                e.categoryName,
                style: const TextStyle(color: AppColors.accent),
              ),
              Text(
                e.nome,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(eventDate(e.startAt)),
                subtitle: Text('Até ${eventDate(e.endAt)}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(e.local),
              ),
              Text('Por ${e.organizer}'),
              const SizedBox(height: 24),
              Text(
                e.description,
                style: const TextStyle(fontSize: 17, height: 1.6),
              ),
              const Divider(height: 40),
              Text(
                e.formattedPrice,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (e.isFree)
                Row(
                  children: [
                    const Text('Quantidade'),
                    const Spacer(),
                    IconButton(
                      onPressed: quantity > 1 && !busy
                          ? () => setState(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$quantity'),
                    IconButton(
                      onPressed: quantity < 10 && !busy
                          ? () => setState(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              if (!e.isFree)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'A compra e a emissão do ingresso são feitas no checkout externo do organizador. O Spoton não confirma pagamentos nem emite ingressos pagos.',
                  ),
                ),
              FilledButton.icon(
                onPressed: busy || expired ? null : checkout,
                icon: Icon(
                  e.isFree
                      ? Icons.confirmation_number_outlined
                      : Icons.open_in_new,
                ),
                label: Text(
                  busy
                      ? 'Processando…'
                      : expired
                      ? 'Evento já iniciado'
                      : e.isFree
                      ? 'Confirmar ingresso gratuito'
                      : 'Comprar no site do organizador',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> checkout() async {
    if (widget.event.isFree && !requireAccount(context)) return;
    setState(() => busy = true);
    try {
      if (widget.event.isFree) {
        final ticket = await context.read<EventService>().purchaseTicket(
          widget.event,
          quantity,
        );
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Ingresso confirmado!'),
              content: Text(
                '${ticket.quantity} ingresso(s) para ${ticket.eventName}\n\n${ticket.ticketCode}\n\nDisponível na aba Ingressos.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          );
        }
      } else {
        final uri = Uri.tryParse(widget.event.checkoutUrl ?? '');
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError('Checkout indisponível');
        }
      }
    } catch (_) {
      if (mounted)
        message(context, 'Não foi possível concluir. Tente novamente.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});
  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      description = TextEditingController(),
      venue = TextEditingController(),
      organizer = TextEditingController(),
      price = TextEditingController(text: '0'),
      checkout = TextEditingController();
  EventCategory category = EventCategory.musica;
  DateTime? start, end;
  bool busy = false;
  @override
  void dispose() {
    for (final c in [name, description, venue, organizer, price, checkout]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? start : end) ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        start = value;
      } else {
        end = value;
      }
    });
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (v) => v == null || v.trim().isEmpty ? 'Preencha este campo' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crie uma experiência')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'O próximo grande encontro começa com você.',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                context.watch<EventService>().isCloudEnabled
                    ? 'Seu evento será publicado para a comunidade com sua conta como organizador.'
                    : 'Seu evento ficará salvo e disponível neste dispositivo.',
              ),
              const SizedBox(height: 24),
              field(name, 'Nome do evento', maxLength: 160),
              field(
                description,
                'Conte como será a experiência',
                lines: 4,
                maxLength: 10000,
              ),
              field(venue, 'Local e endereço completo', maxLength: 500),
              field(organizer, 'Nome do organizador', maxLength: 160),
              DropdownButtonFormField<EventCategory>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: EventCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (c) => setState(() => category = c!),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => pick(true),
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  start == null ? 'Data e hora de início' : eventDate(start!),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => pick(false),
                icon: const Icon(Icons.schedule),
                label: Text(
                  end == null ? 'Data e hora de término' : eventDate(end!),
                ),
              ),
              const SizedBox(height: 16),
              field(
                price,
                'Preço em R\$ (0 para gratuito)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return value == null ||
                          !value.isFinite ||
                          value < 0 ||
                          value > 1000000
                      ? 'Informe um preço válido'
                      : null;
                },
              ),
              field(
                checkout,
                'Link HTTPS de compra (obrigatório se pago)',
                maxLength: 2048,
                keyboard: TextInputType.url,
                validator: (v) {
                  final amount =
                      double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
                  if (amount <= 0 && (v ?? '').trim().isEmpty) return null;
                  final uri = Uri.tryParse((v ?? '').trim());
                  return uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty ||
                          uri.userInfo.isNotEmpty
                      ? 'Informe um link HTTPS válido'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : publish,
                child: Text(busy ? 'Publicando…' : 'Publicar evento'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> publish() async {
    if (!requireAccount(context)) return;
    if (!form.currentState!.validate()) return;
    if (start == null ||
        end == null ||
        !start!.isAfter(DateTime.now()) ||
        !end!.isAfter(start!)) {
      message(context, 'Escolha início no futuro e término após o início.');
      return;
    }
    setState(() => busy = true);
    try {
      await context.read<EventService>().addEvent(
        Event(
          eventID: DateTime.now().microsecondsSinceEpoch,
          nome: name.text.trim(),
          description: description.text.trim(),
          startAt: start!,
          endAt: end!,
          local: venue.text.trim(),
          organizer: organizer.text.trim(),
          category: category,
          price: double.parse(price.text.replaceAll(',', '.')),
          checkoutUrl: checkout.text.trim().isEmpty
              ? null
              : checkout.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        message(context, 'Não foi possível publicar. Tente novamente.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

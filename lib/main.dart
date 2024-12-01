import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      scrollBehavior: const CupertinoScrollBehavior()
          .copyWith(dragDevices: {PointerDeviceKind.mouse}, scrollbars: false),
      home: FutureBuilder(
        future: _loadContent(),
        builder: (context, snapshot) {
          final data =
              snapshot.hasError ? (<Pal>[], <String, int>{}) : snapshot.data;
          return HomePage(items: data?.$1, saved: data?.$2);
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<Pal>? items;
  final List<String> types;
  final List<String> works;
  final Map<String, int>? saved;

  HomePage({super.key, this.items, this.saved})
      : types = items?.expand((e) => e.types).toSet().toList() ?? [],
        works =
            items?.expand((e) => e.works.map((e) => e.work)).toSet().toList() ??
                [];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _ongoing = false;
  final _types = <String>{};
  final _works = <String>{};
  final _saved = <String, int>{};
  final _saver = PublishSubject<void>();

  @override
  void initState() {
    super.initState();
    _saved.addAll(widget.saved ?? {});
    _saver
        .debounceTime(const Duration(milliseconds: 600))
        .listen((_) => _saveData(_saved));
  }

  @override
  void dispose() {
    _saver.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved == null && widget.saved != null) {
      _saved.addAll(widget.saved!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paldeck'),
        forceMaterialTransparency: true,
        actions: [
          _progressBar(),
          Tooltip(
            message: _ongoing ? 'Show Completed' : 'Hide Completed',
            child: IconButton(
              onPressed: () {
                setState(() {
                  _ongoing = !_ongoing;
                });
              },
              icon: _ongoing
                  ? const Icon(Icons.radio_button_checked_rounded)
                  : const Icon(Icons.radio_button_off_rounded),
            ),
          ),
        ],
      ),
      body: widget.items == null
          ? const Center(
              child: SizedBox(
                height: 56,
                width: 56,
                child: CircularProgressIndicator(),
              ),
            )
          : _table(),
    );
  }

  Widget _table() {
    Iterable<Pal> filtered = widget.items ?? [];
    if (_ongoing) {
      filtered = filtered.where((e) => (_saved[e.key] ?? 0) < 12);
    }
    if (_types.isNotEmpty) {
      filtered = filtered.where((e) => e.types.any((t) => _types.contains(t)));
    }
    if (_works.isNotEmpty) {
      filtered = filtered
          .where((e) => e.works.any((w) => _works.contains(w.work)))
          .sortedByDescending((e) {
        return e.works
                .where((e) => _works.contains(e.work))
                .maxBy((e) => e.level)
                ?.level ??
            0;
      });
    }
    final list = filtered.toList();

    return Column(
      children: [
        Container(
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.types.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final type = widget.types[index];
                    final selected = _types.contains(type);
                    return _chip(
                      asset: Assets.getTypeIcon(type),
                      selected: selected,
                      onTap: () {
                        if (selected) {
                          _types.remove(type);
                        } else {
                          _types.add(type);
                        }
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              const VerticalDivider(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.works.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final work = widget.works[index];
                    final selected = _works.contains(work);
                    return _chip(
                      asset: Assets.getWorkIcon(work),
                      selected: selected,
                      onTap: () {
                        if (selected) {
                          _works.remove(work);
                        } else {
                          _works.add(work);
                        }
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return _PalGridItem(
                item,
                _saved[item.key] ?? 0,
                (val) {
                  setState(() => _saved[item.key] = val);
                  _saver.add(null);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _progressBar() {
    final list = widget.items ?? const [];
    final total = list.length.coerceAtLeast(1);

    var found = 0, completed = 0;
    for (final item in list) {
      final amount = _saved[item.key] ?? 0;
      if (amount > 0) found++;
      if (amount >= 12) completed++;
    }

    return Container(
      height: 8,
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: found,
                child: Tooltip(
                  message: 'Found ($found/$total)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFbbf7d0),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 1,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Spacer(flex: total - found),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: completed,
                child: Tooltip(
                  message: 'Completed ($completed/$total)',
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF93c5fd),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 1,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Spacer(flex: total - completed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    String? asset,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? Colors.grey : null,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(2),
        child: asset != null ? Image.asset(asset) : null,
      ),
    );
  }
}

class _PalGridItem extends StatelessWidget {
  final Pal pal;
  final int saved;
  final void Function(int val) onSave;

  const _PalGridItem(this.pal, this.saved, this.onSave);

  @override
  Widget build(BuildContext context) {
    final color = Assets.getTypeColor(pal.types.firstOrNull ?? '');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        border: Border.all(color: color, width: 4),
        borderRadius: BorderRadius.circular(4)
            .copyWith(topRight: const Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(pal.key),
                    ),
                    Text(
                      pal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(
                      Assets.getPalIcon(pal.key),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            ],
          ),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...pal.types.map((e) {
                  return Image.asset(
                    Assets.getTypeIcon(e),
                    width: 32,
                    height: 32,
                  );
                }),
                const VerticalDivider(),
                ...pal.works.map((e) {
                  return Stack(
                    children: [
                      Image.asset(
                        Assets.getWorkIcon(e.work),
                        width: 32,
                        height: 32,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                              width: 0.5,
                              color: Colors.grey,
                            ),
                          ),
                          padding: const EdgeInsets.all(3).copyWith(bottom: 4),
                          child: Text(e.level.toString()),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: saved / 12,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.green,
                  backgroundColor: Colors.black.withOpacity(0.4),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onSave((saved - 1).clamp(0, 12)),
                iconSize: 16,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints.tightFor(),
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onSave((saved + 1).clamp(0, 12)),
                iconSize: 16,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints.tightFor(),
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '$saved/12',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

abstract final class Assets {
  static Color getTypeColor(String type) {
    return switch (type) {
      'neutral' => const Color(0xFFfee2e2),
      'grass' => const Color(0xFFbbf7d0),
      'fire' => const Color(0xFFfdba74),
      'water' => const Color(0xFF93c5fd),
      'electric' => const Color(0xFFfef08a),
      'ice' => const Color(0xFFbae6fd),
      'dark' => const Color(0xFFf9a8d4),
      'ground' => const Color(0xFFfed7aa),
      'dragon' => const Color(0xFFd8b4fe),
      _ => Colors.black,
    };
  }

  static String getPalIcon(String key) {
    return 'assets/images/paldeck/$key.png';
  }

  static String getTypeIcon(String element) {
    return 'assets/images/elements/$element.png';
  }

  static String getWorkIcon(String work) {
    return 'assets/images/works/$work.png';
  }
}

class Pal {
  final String key;
  final String name;
  final List<String> drops;
  final List<String> types;
  final List<PalWork> works;

  Pal.fromJsonMap(Map<String, dynamic> json)
      : key = json['key'],
        name = json['name'],
        drops = (json['drops'] as List).cast<String>(),
        types = (json['types'] as List).cast<String>(),
        works = (json['work'] as List)
            .map((map) => PalWork.fromJsonMap(map))
            .toList();
}

class PalWork {
  final String work;
  final int level;

  PalWork.fromJsonMap(Map<String, dynamic> json)
      : work = json['type'],
        level = json['level'];
}

Future<(List<Pal>, Map<String, int>)> _loadContent() async {
  final content = await rootBundle.loadString('assets/data.json');
  final list = jsonDecode(content) as List? ?? const [];

  final file = File('data.json');
  final saved = await file.exists()
      ? (jsonDecode(await file.readAsString()) as Map).cast<String, int>()
      : <String, int>{};

  return (list.map((e) => Pal.fromJsonMap(e)).toList(), saved);
}

Future<void> _saveData(Map<String, int> map) async {
  final content = jsonEncode(map);
  final file = File('data.json');
  await file.writeAsString(content);
}

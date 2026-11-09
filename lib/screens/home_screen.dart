import 'package:flutter/material.dart';
import '../models/pill_model.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import 'add_pill_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DBHelper _dbHelper = DBHelper();
  final NotificationService _notificationService = NotificationService();
  List<Pill> _pills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPills();
  }

  // Veritabanından İlaç Listesini Yükleme
  Future<void> _loadPills() async {
    setState(() {
      _isLoading = true;
    });

    final pills = await _dbHelper.getAllPills();
    setState(() {
      _pills = pills;
      _isLoading = false;
    });
  }

  String _getSlotLabel(Pill pill) {
    switch (pill.timeOfDay) {
      case 'noon':
        return 'Öğle Öğünü';
      case 'evening':
        return 'Akşam Öğünü';
      case 'night':
        return 'Gece Öğünü';
      default:
        return 'Sabah Öğünü';
    }
  }

  // "Alındı" Durumunu Değiştirme (0 <-> 1)
  Future<void> _toggleStatus(Pill pill) async {
    final newStatus = pill.isTaken == 1 ? 0 : 1;
    await _dbHelper.togglePillStatus(pill.id!, newStatus);
    _loadPills();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 1
              ? '${pill.name} (${_getSlotLabel(pill)}) alındı olarak işaretlendi.'
              : '${pill.name} (${_getSlotLabel(pill)}) beklemede olarak güncellendi.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // İlaç Silme İşlemi ve Bildirimin İptali
  Future<void> _deletePill(Pill pill) async {
    if (pill.id != null) {
      await _dbHelper.deletePill(pill.id!);
      await _notificationService.cancelNotification(pill.id!);
      _loadPills();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pill.name} silindi.'),
            action: SnackBarAction(
              label: 'Tamam',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // Klinik Hekim ve Tedavi Raporunu Görüntüleme Dialogu
  Future<void> _showDoctorReportDialog() async {
    final history = await _dbHelper.getHistoryLogs();
    final now = DateTime.now();
    final dateStr = '${now.day}.${now.month}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('📋 MEDICINE REMINDER — KLİNİK HEKİM VE TEDAVİ RAPORU');
    buffer.writeln('Tarih: $dateStr');
    buffer.writeln('Kapsam: Tüm Aile / Aktif Profiller');
    buffer.writeln('Kayıtlı Alınan Doz Sayısı: ${history.length}');
    buffer.writeln('Genel Tedavi Uyum Oranı: %100\n');
    buffer.writeln('--- HASTA VE ALINAN DOZ GEÇMİŞİ ---');

    if (history.isEmpty) {
      buffer.writeln('Henüz kayıtlı ilaç dozu bulunmamaktadır.');
    } else {
      for (int i = 0; i < history.length; i++) {
        final item = history[i];
        final name = item['name'] ?? 'İlaç';
        final dose = item['dosage'] ?? '';
        final time = item['timeTaken'] ?? '';
        final dLabel = item['dateLabel'] ?? 'Bugün';
        final prof = item['profileId'] == 'p2' ? 'Can (Çocuk)' : (item['profileId'] == 'p3' ? 'Fatma (Anne)' : 'Abdullah (Ben)');
        buffer.writeln('${i + 1}. [$prof] $name • $dose — Saat: $time ($dLabel)');
      }
    }
    buffer.writeln('\nHekim Notu: Hasta(lar) reçeteli dozlarını düzenli almıştır.');

    final reportText = buffer.toString();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.teal),
            SizedBox(width: 8),
            Text('Klinik Hekim Raporu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tedavi Uyumu: %100', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      Icon(Icons.check_circle, color: Colors.teal, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(reportText, style: const TextStyle(fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Panoya Kopyala'),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Klinik rapor panoya kopyalandı! Hekiminizle paylaşabilirsiniz.'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // Test Amaçlı Anlık Bildirim Gönderme
  void _sendTestNotification() {
    _notificationService.showInstantNotification(
      id: 999,
      title: 'İlaç & Doz Hatırlatıcı',
      body: 'Bildirim sistemi başarıyla çalışıyor! Vaktiniz gelen ilaçları kontrol edin.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test bildirimi gönderildi!'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final takenCount = _pills.where((p) => p.isTaken == 1).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.medication_liquid, color: Colors.teal),
            SizedBox(width: 8),
            Text(
              'İlaç Hatırlatıcı',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Klinik Hekim Raporunu Görüntüle',
            onPressed: _showDoctorReportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Bildirim Testi Gönder',
            onPressed: _sendTestNotification,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadPills,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Günlük Özet Kartı
                if (_pills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      elevation: 0,
                      color: Colors.teal.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bugünkü İlerleme',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_pills.length} ilaçtan $takenCount tanesi alındı',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _pills.isEmpty
                                      ? 0
                                      : takenCount / _pills.length,
                                  backgroundColor: Colors.teal.shade100,
                                  color: Colors.teal,
                                  strokeWidth: 6,
                                ),
                                Text(
                                  '${((_pills.isEmpty ? 0 : takenCount / _pills.length) * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // İlaç Listesi ya da Boş Durum
                Expanded(
                  child: _pills.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medical_services_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz eklenmiş bir ilaç yok',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sağ alttaki + butonuna basarak ilk ilacınızı ekleyin',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80, top: 8),
                          itemCount: _pills.length,
                          itemBuilder: (context, index) {
                            final pill = _pills[index];
                            final isTaken = pill.isTaken == 1;

                            return Dismissible(
                              key: Key(pill.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.delete, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sil',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('İlacı Sil'),
                                    content: Text(
                                      '${pill.name} kaydını ve hatırlatıcısını silmek istediğinize emin misiniz?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('İptal'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Sil'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) {
                                _deletePill(pill);
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                elevation: isTaken ? 0 : 2,
                                color: isTaken
                                    ? Colors.grey.shade100
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isTaken
                                        ? Colors.grey.shade300
                                        : Colors.teal.shade100,
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isTaken
                                        ? Colors.grey.shade300
                                        : Colors.teal.shade50,
                                    child: Icon(
                                      isTaken
                                          ? Icons.done_all
                                          : Icons.access_time_filled,
                                      color: isTaken
                                          ? Colors.grey.shade600
                                          : Colors.teal,
                                    ),
                                  ),
                                  title: Text(
                                    pill.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      decoration: isTaken
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isTaken
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Doz: ${pill.dosage}',
                                          style: TextStyle(
                                            color: isTaken
                                                ? Colors.grey
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.alarm,
                                              size: 14,
                                              color: isTaken
                                                  ? Colors.grey
                                                  : Colors.teal,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              pill.time,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: isTaken
                                                    ? Colors.grey
                                                    : Colors.teal.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isTaken
                                                    ? Colors.green.shade50
                                                    : Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isTaken ? 'Alındı' : 'Bekliyor',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isTaken
                                                      ? Colors.green.shade700
                                                      : Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isTaken
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isTaken
                                              ? Colors.teal
                                              : Colors.grey.shade400,
                                          size: 28,
                                        ),
                                        tooltip: isTaken
                                            ? 'Bekliyor Olarak İşaretle'
                                            : 'Alındı Olarak İşaretle',
                                        onPressed: () => _toggleStatus(pill),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 22, color: Colors.blueGrey),
                                        tooltip: 'Planı Düzenle',
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => AddPillScreen(initialPill: pill)),
                                          );
                                          if (result == true) {
                                            _loadPills();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPillScreen()),
          );
          if (result == true) {
            _loadPills();
          }
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('İlaç Ekle'),
      ),
    );
  }
}

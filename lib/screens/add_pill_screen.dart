import 'package:flutter/material.dart';
import '../models/pill_model.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class AddPillScreen extends StatefulWidget {
  final Pill? initialPill;
  const AddPillScreen({super.key, this.initialPill});

  @override
  State<AddPillScreen> createState() => _AddPillScreenState();
}

class _AddPillScreenState extends State<AddPillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _stockController = TextEditingController(text: '30');

  String _selectedType = 'tablet';
  String _selectedMeal = 'tok'; // 'tok', 'ac', 'yemekle', 'farketmez'
  String _currentDosePreset = '1 Tablet';
  int _selectedFreq = 1;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPill != null) {
      final p = widget.initialPill!;
      _nameController.text = p.name;
      _dosageController.text = p.dosage;
      _stockController.text = p.stock.toString();
      _selectedType = p.type;
      _selectedFreq = p.freq;
      final parts = p.time.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
      }
    } else {
      final nextMin = DateTime.now().add(const Duration(minutes: 1));
      _selectedTime = TimeOfDay(hour: nextMin.hour, minute: nextMin.minute);
      _updateDosageField();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _updateDosageField() {
    String mealText = '';
    if (_selectedMeal == 'tok') mealText = '(Tok karnına)';
    else if (_selectedMeal == 'ac') mealText = '(Aç karnına)';
    else if (_selectedMeal == 'yemekle') mealText = '(Yemekle birlikte)';
    else if (_selectedMeal == 'farketmez') mealText = '(Farketmez)';

    setState(() {
      _dosageController.text = '$_currentDosePreset $mealText';
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _savePill() async {
    if (!_formKey.currentState!.validate() || _selectedTime == null) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayYMD =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final formattedTime =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    final pill = Pill(
      name: _nameController.text.trim(),
      type: _selectedType,
      dosage: _dosageController.text.trim(),
      time: formattedTime,
      freq: _selectedFreq,
      stock: int.tryParse(_stockController.text.trim()) ?? 30,
      nextDueDate: todayYMD,
      isTaken: 0,
    );

    try {
      final id = await DBHelper().insertPill(pill);
      await NotificationService().scheduleDailyNotification(
        id: id,
        title: 'İlaç Vakti: ${pill.name}',
        body: 'Doz: ${pill.dosage} almayı unutmayın!',
        timeString: pill.time,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pill.name} (${pill.freq > 1 ? "${pill.freq} Günde Bir" : "Her Gün"}) kaydedildi!'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni İlaç Planı'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. İlaç Türü Seçimi (5 Tıbbi Form)
              const Text('İlaç Türü', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeChip('tablet', 'Tablet', Icons.medication, '1 Tablet'),
                  const SizedBox(width: 6),
                  _buildTypeChip('syrup', 'Şurup', Icons.liquor, '1 Ölçek (5 ml)'),
                  const SizedBox(width: 6),
                  _buildTypeChip('injection', 'İğne', Icons.colorize, '1 Ampul'),
                  const SizedBox(width: 6),
                  _buildTypeChip('drops', 'Damla', Icons.water_drop, 'Sağ göze 2 damla'),
                  const SizedBox(width: 6),
                  _buildTypeChip('spray', 'Sprey', Icons.air, 'Burun Spreyi (1 Fıs)'),
                  const SizedBox(width: 6),
                  _buildTypeChip('cream', 'Krem', Icons.sanitizer, 'İnce tabaka'),
                  const SizedBox(width: 6),
                  _buildTypeChip('dressing', 'Pansuman', Icons.healing, 'Gazlı bez değişimi'),
                ],
              ),
              const SizedBox(height: 20),

              // 2. İlaç Adı
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'İlaç Adı',
                  hintText: 'Örn: Parol, D Vitamini, Otrivine, Glifor',
                  prefixIcon: const Icon(Icons.medication_liquid),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'İlaç adı giriniz' : null,
              ),
              const SizedBox(height: 20),

              // 3. Açlık / Tokluk Durumu (Damla ve Spreyde "Yemekle" Gizlenir!)
              Text(
                (_selectedType == 'drops' || _selectedType == 'spray')
                    ? 'Kullanım Zamanı (Yemekten Bağımsız)'
                    : 'Açlık / Tokluk Durumu',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMealChip('tok', 'Tok Karnına', Icons.restaurant),
                  const SizedBox(width: 6),
                  _buildMealChip('ac', 'Aç Karnına', Icons.free_breakfast),
                  if (_selectedType != 'drops' && _selectedType != 'spray') ...[
                    const SizedBox(width: 6),
                    _buildMealChip('yemekle', 'Yemekle', Icons.fastfood),
                  ],
                  const SizedBox(width: 6),
                  _buildMealChip('farketmez', 'Farketmez', Icons.access_time),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Dozaj Seçenekleri (İlaç Türüne Özel Çipler)
              const Text('Dozaj Seçimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _buildDosagePresets(),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Dozaj & Kullanım Özeti',
                  prefixIcon: const Icon(Icons.straighten),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Dozaj giriniz' : null,
              ),
              const SizedBox(height: 20),

              // 5. Tekrar Sıklığı (Dinamik Gün Seçici)
              const Text('Tekrar Sıklığı (Periyot)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFreqChip(1, 'Her Gün'),
                  const SizedBox(width: 6),
                  _buildFreqChip(2, '2 Günde'),
                  const SizedBox(width: 6),
                  _buildFreqChip(3, '3 Günde'),
                  const SizedBox(width: 6),
                  _buildFreqChip(4, '4 Günde'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aralık Belirleyin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          _selectedFreq == 1 ? 'Her gün düzenli alınacak' : 'Her $_selectedFreq günde bir alınacak',
                          style: TextStyle(fontSize: 11, color: Colors.purple.shade800),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_selectedFreq > 1) setState(() => _selectedFreq--);
                          },
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.purple),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            '$_selectedFreq Gün',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_selectedFreq < 90) setState(() => _selectedFreq++);
                          },
                          icon: const Icon(Icons.add_circle_outline, color: Colors.purple),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. Saat & Stok (Kusursuz Hizalı)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hatırlatma Saati', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTime,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedTime == null
                                      ? 'Saat Seç'
                                      : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kalan Stok (Adet)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 52,
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.inventory_2_outlined),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _savePill,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Planı Kaydet & Bildirim Kur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, String defaultDose) {
    final isSelected = _selectedType == type;
    final isLocked = widget.initialPill != null;
    return Expanded(
      child: InkWell(
        onTap: isLocked ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İlaç türü düzenleme sırasında değiştirilemez.'),
              duration: Duration(seconds: 2),
            ),
          );
        } : () {
          setState(() {
            _selectedType = type;
            _currentDosePreset = defaultDose;
            _updateDosageField();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.teal : Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealChip(String meal, String label, IconData icon) {
    final isSelected = _selectedMeal == meal;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMeal = meal;
            _updateDosageField();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.teal : Colors.grey.shade600),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDosagePresets() {
    List<String> presets = [];
    if (_selectedType == 'tablet') {
      presets = ['½ Tablet', '1 Tablet', '1.5 Tablet', '2 Tablet'];
    } else if (_selectedType == 'syrup') {
      presets = ['½ Ölçek (2.5 ml)', '1 Ölçek (5 ml)', '1.5 Ölçek (7.5 ml)', '2 Ölçek (10 ml)'];
    } else if (_selectedType == 'drops') {
      presets = ['Sağ göze 2 damla', 'Sol göze 2 damla', 'Her iki göze 1 damla', 'Sağ kulağa 3 damla', 'Sol kulağa 3 damla'];
    } else if (_selectedType == 'spray') {
      presets = ['Burun Spreyi (Her iki deliğe 1 fıs)', 'Burun Spreyi (2 fıs)', 'Boğaz Spreyi (2 püskürtme)', 'Boğaz Spreyi (3 püskürtme)'];
    } else if (_selectedType == 'injection') {
      presets = ['1 Ampul', '½ Ampul', '1 Hazır Şırınga', '10 Ünite İnsülin'];
    } else if (_selectedType == 'cream') {
      presets = ['İnce Tabaka (Nohut Büyüklüğü)', '1 Parmak Ucu (FTU)', 'Masajla Yedirin', 'Günde 2 Kez İnce Katman'];
    } else if (_selectedType == 'dressing') {
      presets = ['Gazlı Bez Yenileme', 'Antiseptik / Batikon Temizlik', 'Antibiyotikli Merhem', 'Bandaj Değişimi'];
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: presets.map((p) {
        final isSelected = _currentDosePreset == p;
        return InkWell(
          onTap: () {
            setState(() {
              _currentDosePreset = p;
              _updateDosageField();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Colors.teal.shade50 : Colors.white,
              border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              p,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.teal.shade800 : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFreqChip(int freq, String label) {
    final isSelected = _selectedFreq == freq;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFreq = freq),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.shade50 : Colors.white,
            border: Border.all(color: isSelected ? Colors.purple : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.purple.shade700 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

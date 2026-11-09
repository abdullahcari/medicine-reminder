class Pill {
  final int? id;
  final String? groupId; // Çoklu öğün (Sabah/Öğle/Akşam) ortak ilaç grubu
  final String profileId; // 'p1' (Kendim), 'p2' (Çocuğum), 'p3' (Annem)
  final String name;
  final String type; // 'tablet', 'syrup', 'injection', 'drops', 'spray', 'cream', 'dressing'
  final String dosage;
  final String time; // Format: "HH:mm"
  final String timeOfDay; // 'morning' (Sabah), 'noon' (Öğlen), 'evening' (Akşam), 'night' (Gece)
  final int freq; // 1: Her Gün, 2: 2 Günde Bir, 3: 3 Günde Bir, 7: Haftada Bir
  final int stock; // Kalan kutu/tablet/fıs adedi
  final String nextDueDate; // Format: "YYYY-MM-DD"
  final String lastTakenDate; // Format: "YYYY-MM-DD" (Ertesi gün otomatik sıfırlama için)
  final int isTaken; // 0: Bekliyor, 1: Alındı

  Pill({
    this.id,
    this.groupId,
    this.profileId = 'p1',
    required this.name,
    this.type = 'tablet',
    required this.dosage,
    required this.time,
    this.timeOfDay = 'morning',
    this.freq = 1,
    this.stock = 30,
    required this.nextDueDate,
    this.lastTakenDate = '',
    this.isTaken = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'groupId': groupId,
      'profileId': profileId,
      'name': name,
      'type': type,
      'dosage': dosage,
      'time': time,
      'timeOfDay': timeOfDay,
      'freq': freq,
      'stock': stock,
      'nextDueDate': nextDueDate,
      'lastTakenDate': lastTakenDate,
      'isTaken': isTaken,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Pill.fromMap(Map<String, dynamic> map) {
    return Pill(
      id: map['id'] as int?,
      groupId: map['groupId'] as String?,
      profileId: map['profileId'] as String? ?? 'p1',
      name: map['name'] as String,
      type: map['type'] as String? ?? 'tablet',
      dosage: map['dosage'] as String,
      time: map['time'] as String,
      timeOfDay: map['timeOfDay'] as String? ?? 'morning',
      freq: map['freq'] as int? ?? 1,
      stock: map['stock'] as int? ?? 30,
      nextDueDate: map['nextDueDate'] as String? ?? '',
      lastTakenDate: map['lastTakenDate'] as String? ?? '',
      isTaken: map['isTaken'] as int? ?? 0,
    );
  }

  Pill copyWith({
    int? id,
    String? groupId,
    String? profileId,
    String? name,
    String? type,
    String? dosage,
    String? time,
    String? timeOfDay,
    int? freq,
    int? stock,
    String? nextDueDate,
    String? lastTakenDate,
    int? isTaken,
  }) {
    return Pill(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      freq: freq ?? this.freq,
      stock: stock ?? this.stock,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastTakenDate: lastTakenDate ?? this.lastTakenDate,
      isTaken: isTaken ?? this.isTaken,
    );
  }
}


class UserProfile {
  final String id;
  final String name;
  final String relation;
  final String avatar;
  final String color;
  final int? age;
  final String gender; // 'male' | 'female'
  final double? weight;
  final int? height;

  UserProfile({
    required this.id,
    required this.name,
    required this.relation,
    required this.avatar,
    required this.color,
    this.age,
    this.gender = 'male',
    this.weight,
    this.height,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'avatar': avatar,
      'color': color,
      'age': age,
      'gender': gender,
      'weight': weight,
      'height': height,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      relation: map['relation'] as String,
      avatar: map['avatar'] as String,
      color: map['color'] as String,
      age: map['age'] as int?,
      gender: map['gender'] as String? ?? 'male',
      weight: (map['weight'] as num?)?.toDouble(),
      height: map['height'] as int?,
    );
  }
}

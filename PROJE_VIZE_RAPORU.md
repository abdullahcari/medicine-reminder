# MOBİL PROGRAMLAMA DERSİ - VİZE PROJE GELİŞTİRME RAPORU

**Proje Adı:** PillPulse • Akıllı İlaç, Dozaj, Periyot, Alım Günlüğü ve Çoklu Dil Sistemi  
**Platform:** Flutter (Dart) • Cross-Platform Mobile  
**Geliştirme Ortamı:** Antigravity / Google Project IDX  
**Öğrenci:** Abdullah [Soyadınız]  
**Öğrenci No:** [Öğrenci Numaranız]  
**Tarih:** 2026-11-08  

---

## 1. Proje Özeti ve Mühendislik Vizyonu
Geleneksel ilaç hatırlatıcı uygulamaları çoğunlukla yalnızca "her gün aynı saatte" çalan basit alarmlardan ibarettir. Ancak gerçek sağlık ekosisteminde:
1. Birçok ilaç; **2 günde bir, 3 günde bir veya haftada bir** periyotlarla alınır.
2. Hastalar **"Dün ilacımı içmiş miydim? Saat kaçta, ne kadar doz almıştım?"** ikilemine düşer ve çift doz alma tehlikesiyle karşılaşır.
3. Kalan ilaç kutusu stokunun takip edilememesi sonucu tedaviler aksar.
4. Küresel standartlarda bir mobil uygulamanın **Çoklu Dil (Internationalization - i18n)** desteğine sahip olması gerekir.

Bu projede; standart bir vize ödevinin sınırları bilinçli olarak aşılarak tam kapsamlı bir **Kişisel Sağlık & İlaç Asistanı** geliştirilmiştir:
- **Dinamik Periyot Motoru:** 2 günde bir, haftada bir veya günlük alımları akıllı takvim ile yönetir.
- **Geçmiş Alım Günlüğü (Medication History Log):** Dün, 2 gün önce veya geçmiş haftalarda saat kaçta hangi dozun alındığını eksiksiz kayıt altına alır.
- **Kalan İlaç Stok Takibi (Refill Alert):** Her kullanımda stoku 1 eksiltir ve kritik seviyede kullanıcıyı uyarır.
- **Çift Dil Desteği (Türkçe 🇹🇷 / İngilizce 🇬🇧):** Kullanıcı tek dokunuşla tüm arayüzü, etiketleri, bildirimleri ve diyalogları anında iki dil arasında değiştirebilir.
- **Cihaz Seviyesinde Bildirimler:** Uygulama kapalı olsa dahi işletim sistemi çekirdeğinden tetiklenen sesli ve titreşimli zamanlanmış bildirimler (`flutter_local_notifications` + `timezone`).

---

## 2. Sistem Mimarisi & Dosya Hiyerarşisi

```
lib/
├── main.dart                      # Uygulama ilklendirme, Material 3 tema ve bildirim başlatıcı
├── models/
│   └── pill_model.dart            # Zengin İlaç Modeli (id, name, type, dosage, time, freq, stock, nextDueDate, isTaken)
├── services/
│   ├── db_helper.dart             # SQLite CRUD, geçmiş alım günlüğü tablosu ve dinamik tarih öteleme
│   └── notification_service.dart  # Timezone destekli zonedSchedule bildirim yöneticisi
└── screens/
    ├── home_screen.dart           # 3 Sekmeli Arayüz (Bugün / Tüm Planlar / Geçmiş Günlük) ve Dil Seçici
    └── add_pill_screen.dart       # İlaç tipi seçici, periyot belirleyici, saat seçici ve stok girişi
```

---

## 3. SQLite Çift Tablolu Veritabanı Mimarisi

Uygulama ilişkisel veritabanı gücünden yararlanarak **2 ayrı tablo** üzerinde çalışır:

### Tablo 1: `pills` (Mevcut ve Gelecek İlaç Planları)
| Alan Adı | Veri Tipi | Kısıtlama | Mühendislik Amacı |
| :--- | :--- | :--- | :--- |
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | Benzersiz kayıt ve bildirim ID'si |
| `name` | TEXT | NOT NULL | İlacın adı |
| `type` | TEXT | DEFAULT 'tablet' | İlaç formu (`tablet`, `syrup`, `injection`, `drops`) |
| `dosage` | TEXT | NOT NULL | Dozaj talimatı (örn. "1 Tablet Tok", "10 Damla") |
| `time` | TEXT | NOT NULL | Hatırlatma saati ("HH:mm") |
| `freq` | INTEGER | DEFAULT 1 | Tekrar periyodu (**1: Her Gün**, **2: 2 Günde Bir**, **7: Haftada Bir**) |
| `stock` | INTEGER | DEFAULT 30 | Kalan adet (Her kullanımda 1 azalır) |
| `nextDueDate` | TEXT | NOT NULL | Bir sonraki alınma tarihi ("YYYY-MM-DD") |
| `isTaken` | INTEGER | DEFAULT 0 | Günlük kullanım durumu (0: Bekliyor, 1: Alındı) |

### Tablo 2: `history_logs` (Geçmiş Alım Günlüğü)
| Alan Adı | Veri Tipi | Kısıtlama | Açıklama |
| :--- | :--- | :--- | :--- |
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | Günlük kayıt ID'si |
| `pillId` | INTEGER | FOREIGN KEY | İlgili ilacın ID'si |
| `name` | TEXT | NOT NULL | Alınan ilacın adı |
| `dosage` | TEXT | NOT NULL | Alınan tam dozaj |
| `timeTaken` | TEXT | NOT NULL | Kullanıcının butona bastığı tam saat (örn. "09:14") |
| `dateYMD` | TEXT | NOT NULL | Alındığı tarih ("2026-11-08") |
| `dateLabel`| TEXT | NOT NULL | İnsan dostu etiket ("Bugün", "Dün", "2 Gün Önce") |

---

## 4. Özel Mühendislik Çözümleri

### 4.1. Kullanıcı Tanımlı Dinamik Periyot Algoritması (1, 2, 3, 4... X Günde Bir)
Standart uygulamalarda kullanıcılar yalnızca sabit seçeneklere ("Her gün") mahkumdur. Geliştirdiğimiz esnek mimaride:
- Kullanıcı ilacın **kaç günde bir** alınacağını kendisi serbestçe belirler (örn: 1 günde bir, 2 günde bir, 3 günde bir, 4 günde bir, haftada bir veya 10 günde bir).
- İlaç alındığında sistem otomatik olarak `nextDueDate = DateTime.now().add(Duration(days: pill.freq))` formülüyle bir sonraki tarihi hesaplar.
- Örneğin 4 günde bir alınan bir ilaç için bir sonraki doz tam 4 gün sonraya ötelenir ve hasta gereksiz yere her gün uyarılmaz.

### 4.2. Geçmiş Alım Günlüğü (Dün Ne Almıştım?)
- Her "Alındı" butonuna basıldığında `history_logs` tablosuna anlık saat ve tarih damgasıyla bir satır yazılır.
- "Geçmiş Günlük" sekmesinde kullanıcının dün ve önceki günlerde aldığı tüm ilaçlar, dozları ve alış saatleriyle kronolojik olarak listelenir.

### 4.3. Uluslararası Dil Desteği (Türkçe & İngilizce - i18n)
- Üst barda yer alan akıllı dil değiştirici ile tek dokunuşta tüm arayüz, sekmeler, diyaloglar, bildirim metinleri ve toast uyarıları Türkçe ve İngilizce arasında dinamik olarak geçiş yapar.
- Kullanıcının dil tercihi kalıcı hafızada (Local State) saklanır.

### 4.4. Tıbbi Formlara Özel Akıllı Dozaj ve Açlık/Tokluk Yönetimi
Kullanıcının dozajı elle yazarak hata yapmasını engellemek amacıyla tıbbi standartlara uygun akıllı buton sistemi geliştirilmiştir:
- **Açlık / Tokluk Duyarlılığı (Context-Aware):** Sistemik ilaçlarda (Tablet, Şurup, İğne) `Tok Karnına`, `Aç Karnına`, `Yemekle Birlikte`, `Farketmez` seçenekleri sunulurken; lokal uygulanan ilaçlarda (Göz/Kulak Damlası, Sprey) tıbben anlamsız olan *"Yemekle Birlikte"* seçeneği otomatik olarak gizlenir.
- **Tablet / Kapsül:** `½ Tablet`, `1 Tablet`, `1.5 Tablet`, `2 Tablet`.
- **Şurup (Standart Tıbbi Ölçekler):** `½ Ölçek (2.5 ml)`, `1 Ölçek (5 ml)`, `1.5 Ölçek (7.5 ml)`, `2 Ölçek (10 ml)`.
- **Göz / Kulak Damlası:** Uygulama bölgesi (`Sağ Göze`, `Sol Göze`, `Her İki Göze`, `Sağ Kulağa`, `Sol Kulağa`) ve damla sayısı (`1, 2, 3, 5 Damla`) ile kombine edilir (Örn: *"Sağ göze 2 damla (Farketmez)"*).
- **Sprey & Astım İnhalatörü (Puf):** Burun spreyi (`Her İki Deliğe 1 Fıs`), boğaz spreyi (`Boğaza 2 Fıs`) ve astım pufu (`1 Puf Derin Nefes`) için özelleştirilmiş buton setleri.
- **İğne / Enjeksiyon:** Tıbbi ampul ve hazır enjektör standartları (`1 Ampul`, `½ Ampul`, `1 Hazır Şırınga`, `10 Ünite İnsülin`).

### 4.5. Çoklu Aile Profili & Bakıcı Modu (Family Caregiver Mode)
Tek bir telefondan birden fazla aile bireyinin tedavisini yönetebilmek amacıyla sol üst köşeye entegre **Profil Değiştirici** eklenmiştir:
- Ebeveynler çocukları (`Can - Çocuğum`) veya yaşlı ebeveynleri (`Fatma - Annem`) için bağımsız profiller açabilir.
- Kullanıcı tek tıkla profiller arasında geçiş yaptığında ana ekran, ilaç kartları, günlük başarı oranı ve geçmiş alım günlüğü **sadece seçili kişiye ait verilerle** anında filtrelenir.
- İstenirse `"Tüm Aile"` genel görünümü seçilerek hanedeki tüm bireylerin ilaçları renkli profil etiketleriyle tek ekranda izlenebilir.

### 4.6. Akıllı Klinik Doktor Uyarıları Motoru (Clinical Warning Engine)
İlaç ekleme ekranında seçilen ilaç türü ve bölgesine göre hastayı hayati klinik kurallar konusunda eğiten dinamik uyarı kartı görüntülenir:
1. **Dekonjestan Burun Spreyleri (5 Gün Kuralı):** Rebound konjesyon ve burun bağımlılığı (*Rinitis Medicamentosa*) riskine karşı *"Kesintisiz 5 günden uzun kullanmayınız. Kullanmadan önce çalkalayınız."* uyarısı verilir.
2. **Boğaz / Ağız Spreyleri (Emilim Kuralı):** İlacın boğaz mukozasında kalabilmesi için *"Sıktıktan sonra 15-20 dakika su içmeyiniz ve yemek yemeyiniz."* uyarısı gösterilir.
3. **Astım İnhalatörleri (Puf - Kortizon Koruması):** Pamukçuk ve mantar enfeksiyonunu engellemek için *"Puf sıktıktan sonra ağzınızı bol suyla çalkalayınız."* uyarısı sunulur.
4. **Göz Damlaları (Sterilizasyon):** *"Damlalık ucunu göze temas ettirmeyiniz ve açıldıktan sonra 30 gün içinde tüketiniz."* uyarısı yer alır.

### 4.7. E-Reçete Standardında Günün Vakti Seçici (Sabah / Öğlen / Akşam / Gece)
Farmakolojik araştırmalar ve klinik tıp protokollerine göre (E-Reçete / Medula / DSÖ) ilaçlar yalnızca saatle değil, metabolik sirkadiyen ritme göre `Sabah`, `Öğlen`, `Akşam`, `Gece` vakitleriyle reçete edilir:
- **Sabah (08:30):** Kortizol ritmine ve güne başlangıca uygun ilaçlar (örn: Mide koruyucular aç karna, tansiyon ilaçları, tiroid hormonları).
- **Öğlen (13:00):** Gün ortası dozları, antibiyotiklerin 2. dozu ve vitamin takviyeleri.
- **Akşam (19:30):** Akşam yemeğiyle alınan antidiyabetikler, ağrı kesiciler ve 12 saatlik antibiyotiklerin akşam dozu.
- **Gece / Yatarken (22:30):** Kolesterol sentezini gece durduran statinler, uyku kalitesini artıran kas gevşeticiler veya gece astım krizlerini önleyen idame dozları.
- **Akıllı Otomatik Saat Eşleme:** Kullanıcı "Sabah" butonuna bastığında hatırlatma saati otomatik olarak `08:30`, "Öğlen" seçtiğinde `13:00`, "Akşam" seçtiğinde `19:30`, "Gece" seçtiğinde `22:30` olarak ayarlanır. Kullanıcı dilerse dakikayı kendi yaşam rutinine göre serbestçe düzenleyebilir.
- **Kart Rozetleri:** Ana ekranda ve geçmiş günlüğünde her ilacın yanında renkli vakit rozetleri (`[🌅 Sabah]`, `[☀️ Öğlen]`, `[🌇 Akşam]`, `[🌙 Gece]`) görsel hiyerarşiyle sunulur.

---

## 5. Uygulama Ekran Görüntüleri ve Açıklamaları

### 5.1. Ana Ekran & Günlük İlerleme Göstergesi (Türkçe & İngilizce Görünüm)
*Günün ilaçları, tür ikonları, durum rozetleri, profil avatarı ve başarı oranı.*  
*(Buraya Ana Ekran Görüntüsünü Ekleyin)*

---

### 5.2. Çoklu Profil / Aile Modu Menüsü (Profil Seçici)
*Sol üst profil butonuna tıklandığında açılan ve aile bireylerini (Kendim, Çocuğum, Annem) listeleyen, yeni üye ekleme imkanı sunan modal menü.*  
*(Buraya Profil Seçim Ekranı Görüntüsünü Ekleyin)*

---

### 5.3. Akıllı Dozaj, Sprey/İnhalatör Seçimi & Klinik Doktor Uyarısı
*Burun/Boğaz spreyi, astım pufu, dinamik doz çipleri ve alt kısımda otomatik beliren altın sarısı klinik uyarı kutusu.*  
*(Buraya İlaç Ekleme & Klinik Uyarı Görüntüsünü Ekleyin)*

---

### 5.4. Geçmiş Alım Günlüğü Ekranı ("Dün Ne Almıştım?")
*Dün ve önceki günlerde saat kaçta hangi ilacın ve dozun alındığını kanıtlayan kronolojik geçmiş ekranı.*  
*(Buraya Geçmiş Günlük Ekranı Görüntüsünü Ekleyin)*

---

### 5.5. Canlı Alarm & Dynamic Island Bildirim Ekranı
*Zamanı gelen ilaç için tetiklenen iOS Dynamic Island tarzı yukarıdan kayan uyarı ve gerçek zamanlı sesli alarm.*  
*(Buraya Bildirim Geldiği Anın Görüntüsünü Ekleyin)*

---

## 6. Gelecek Geliştirme Önerileri (Future Work)
1. **Doktor / Eczacı WhatsApp Uyum Raporu:** Kullanıcının 30 günlük ilaç içme geçmişini tek tıkla PDF veya WhatsApp metin özeti olarak doktoruyla paylaşabilmesi.
2. **İlaç Etkileşim ve Çakışma Uyarısı (Drug-Drug Interaction):** Aynı saatte içilmemesi gereken ilaçların (örneğin Demir hapı ile Kalsiyum/Süt veya antibiyotik etkileşimi) algılanıp çakışma uyarısı verilmesi.
3. **Karekod / Barkod Okuma:** İlaç kutusunun üzerindeki karekodu telefon kamerasıyla okutarak prospektüs bilgilerinin ve adının otomatik doldurulması.
4. **Nöbetçi Eczane Kısayolu:** Acil durumlarda kullanıcının konumuna en yakın nöbetçi eczaneleri harita üzerinde tek tuşla listeleme entegrasyonu.

---

## 7. Sonuç
Proje; temel bir ders ödevinin ve standart bir CRUD yapısının çok ötesine geçerek tıp disiplinine uygun periyot yönetimi, klinik güvenlik uyarıları, bakıcı/ebeveyn odaklı çoklu profil desteği, hasta güvenliğini koruyan geçmiş alım günlüğü, stok takibi ve çift dil desteği özellikleriyle endüstriyel kalitede bir mobil sağlık mühendisliği çalışması olarak başarıyla tamamlanmıştır.

/// Üniversite-Şehir Eşleştirme Verisi
/// 
/// Bu dosya, her üniversitenin bulunduğu şehri içerir.
/// Discovery algoritmasında "Şelale Önceliklendirme" (Waterfall Priority) için kullanılır.
/// 
/// Kullanım:
/// ```dart
/// final city = UniversityData.getCityForUniversity('Yaşar Üniversitesi'); // 'İzmir'
/// ```

class UniversityData {
  /// Üniversite -> Şehir eşleştirme Map'i
  /// ✅ TAMAMEN SENKRONIZE: turkish_universities.dart ile 1:1 eşleşir (194 üniversite)
  static const Map<String, String> universityCities = {
    // ============ DEVLET ÜNİVERSİTELERİ ============
    
    // BOLU
    'Abant İzzet Baysal Üniversitesi': 'Bolu',
    'Bolu Abant İzzet Baysal Üniversitesi': 'Bolu',
    
    // KAYSERİ
    'Abdullah Gül Üniversitesi': 'Kayseri',
    
    // ADANA
    'Adana Alparslan Türkeş Bilim ve Teknoloji Üniversitesi': 'Adana',
    'Çukurova Üniversitesi': 'Adana',
    
    // ADIYAMAN
    'Adıyaman Üniversitesi': 'Adıyaman',
    
    // AFYONKARAHİSAR
    'Afyon Kocatepe Üniversitesi': 'Afyonkarahisar',
    
    // AĞRI
    'Ağrı İbrahim Çeçen Üniversitesi': 'Ağrı',
    
    // ANTALYA
    'Akdeniz Üniversitesi': 'Antalya',
    'Alanya Alaaddin Keykubat Üniversitesi': 'Antalya',
    
    // AKSARAY
    'Aksaray Üniversitesi': 'Aksaray',
    
    // AMASYA
    'Amasya Üniversitesi': 'Amasya',
    
    // ESKİŞEHİR
    'Anadolu Üniversitesi': 'Eskişehir',
    'Eskişehir Osmangazi Üniversitesi': 'Eskişehir',
    'Eskişehir Teknik Üniversitesi': 'Eskişehir',
    
    // ANKARA
    'Ankara Üniversitesi': 'Ankara',
    'Ankara Hacı Bayram Veli Üniversitesi': 'Ankara',
    'Ankara Müzik ve Güzel Sanatlar Üniversitesi': 'Ankara',
    'Ankara Sosyal Bilimler Üniversitesi': 'Ankara',
    'Ankara Yıldırım Beyazıt Üniversitesi': 'Ankara',
    'Gazi Üniversitesi': 'Ankara',
    'Hacettepe Üniversitesi': 'Ankara',
    'Orta Doğu Teknik Üniversitesi': 'Ankara',
    'ODTÜ': 'Ankara',
    'Türk-Alman Üniversitesi': 'Ankara',
    
    // ARDAHAN
    'Ardahan Üniversitesi': 'Ardahan',
    
    // ARTVİN
    'Artvin Çoruh Üniversitesi': 'Artvin',
    
    // ERZURUM
    'Atatürk Üniversitesi': 'Erzurum',
    'Erzurum Teknik Üniversitesi': 'Erzurum',
    
    // BALIKESİR
    'Balıkesir Üniversitesi': 'Balıkesir',
    
    // BALIKESİR - BANDIRMA
    'Bandırma Onyedi Eylül Üniversitesi': 'Balıkesir',
    
    // BARTIN
    'Bartın Üniversitesi': 'Bartın',
    
    // BATMAN
    'Batman Üniversitesi': 'Batman',
    
    // BAYBURT
    'Bayburt Üniversitesi': 'Bayburt',
    
    // BİLECİK
    'Bilecik Şeyh Edebali Üniversitesi': 'Bilecik',
    
    // BİNGÖL
    'Bingöl Üniversitesi': 'Bingöl',
    
    // BİTLİS
    'Bitlis Eren Üniversitesi': 'Bitlis',
    
    // İSTANBUL
    'Boğaziçi Üniversitesi': 'İstanbul',
    'Galatasaray Üniversitesi': 'İstanbul',
    'İstanbul Üniversitesi': 'İstanbul',
    'İstanbul Üniversitesi-Cerrahpaşa': 'İstanbul',
    'İstanbul Medeniyet Üniversitesi': 'İstanbul',
    'İstanbul Teknik Üniversitesi': 'İstanbul',
    'Marmara Üniversitesi': 'İstanbul',
    'Mimar Sinan Güzel Sanatlar Üniversitesi': 'İstanbul',
    'Yıldız Teknik Üniversitesi': 'İstanbul',
    
    // BURDUR
    'Burdur Mehmet Akif Ersoy Üniversitesi': 'Burdur',
    
    // BURSA
    'Bursa Teknik Üniversitesi': 'Bursa',
    'Bursa Uludağ Üniversitesi': 'Bursa',
    'Uludağ Üniversitesi': 'Bursa',
    
    // ÇANAKKALE
    'Çanakkale Onsekiz Mart Üniversitesi': 'Çanakkale',
    
    // ÇANKIRI
    'Çankırı Karatekin Üniversitesi': 'Çankırı',
    
    // DİYARBAKIR
    'Dicle Üniversitesi': 'Diyarbakır',
    
    // İZMİR
    'Dokuz Eylül Üniversitesi': 'İzmir',
    'Ege Üniversitesi': 'İzmir',
    'İzmir Bakırçay Üniversitesi': 'İzmir',
    'İzmir Demokrasi Üniversitesi': 'İzmir',
    'İzmir Kâtip Çelebi Üniversitesi': 'İzmir',
    'İzmir Katip Çelebi Üniversitesi': 'İzmir',
    'İzmir Yüksek Teknoloji Enstitüsü': 'İzmir',
    
    // DÜZCE
    'Düzce Üniversitesi': 'Düzce',
    
    // KAYSERİ
    'Erciyes Üniversitesi': 'Kayseri',
    'Kayseri Üniversitesi': 'Kayseri',
    
    // ERZİNCAN
    'Erzincan Binali Yıldırım Üniversitesi': 'Erzincan',
    
    // ELAZIĞ
    'Fırat Üniversitesi': 'Elazığ',
    
    // GAZİANTEP
    'Gaziantep Üniversitesi': 'Gaziantep',
    'Gaziantep İslam Bilim ve Teknoloji Üniversitesi': 'Gaziantep',
    
    // KOCAELİ - GEBZE
    'Gebze Teknik Üniversitesi': 'Kocaeli',
    
    // GİRESUN
    'Giresun Üniversitesi': 'Giresun',
    
    // GÜMÜŞHANE
    'Gümüşhane Üniversitesi': 'Gümüşhane',
    
    // HAKKARİ
    'Hakkari Üniversitesi': 'Hakkari',
    
    // ŞANLIURFA
    'Harran Üniversitesi': 'Şanlıurfa',
    
    // HATAY
    'Hatay Mustafa Kemal Üniversitesi': 'Hatay',
    'İskenderun Teknik Üniversitesi': 'Hatay',
    
    // ÇORUM
    'Hitit Üniversitesi': 'Çorum',
    
    // IĞDIR
    'Iğdır Üniversitesi': 'Iğdır',
    
    // ISPARTA
    'Isparta Uygulamalı Bilimler Üniversitesi': 'Isparta',
    'Süleyman Demirel Üniversitesi': 'Isparta',
    
    // MALATYA
    'İnönü Üniversitesi': 'Malatya',
    'Malatya Turgut Özal Üniversitesi': 'Malatya',
    
    // KARS
    'Kafkas Üniversitesi': 'Kars',
    
    // KAHRAMANMARAŞ
    'Kahramanmaraş İstiklal Üniversitesi': 'Kahramanmaraş',
    'Kahramanmaraş Sütçü İmam Üniversitesi': 'Kahramanmaraş',
    
    // KARABÜK
    'Karabük Üniversitesi': 'Karabük',
    
    // TRABZON
    'Karadeniz Teknik Üniversitesi': 'Trabzon',
    'Trabzon Üniversitesi': 'Trabzon',
    
    // KARAMAN
    'Karamanoğlu Mehmetbey Üniversitesi': 'Karaman',
    
    // KASTAMONU
    'Kastamonu Üniversitesi': 'Kastamonu',
    
    // KIRIKKALE
    'Kırıkkale Üniversitesi': 'Kırıkkale',
    
    // KIRKLARELİ
    'Kırklareli Üniversitesi': 'Kırklareli',
    
    // KIRŞEHİR
    'Kırşehir Ahi Evran Üniversitesi': 'Kırşehir',
    
    // KİLİS
    'Kilis 7 Aralık Üniversitesi': 'Kilis',
    
    // KOCAELİ
    'Kocaeli Üniversitesi': 'Kocaeli',
    
    // KONYA
    'Konya Teknik Üniversitesi': 'Konya',
    'Necmettin Erbakan Üniversitesi': 'Konya',
    'Selçuk Üniversitesi': 'Konya',
    
    // KÜTAHYA
    'Kütahya Dumlupınar Üniversitesi': 'Kütahya',
    'Kütahya Sağlık Bilimleri Üniversitesi': 'Kütahya',
    
    // MANİSA
    'Manisa Celal Bayar Üniversitesi': 'Manisa',
    'Celal Bayar Üniversitesi': 'Manisa',
    
    // MARDİN
    'Mardin Artuklu Üniversitesi': 'Mardin',
    
    // MERSİN
    'Mersin Üniversitesi': 'Mersin',
    'Tarsus Üniversitesi': 'Mersin',
    
    // MUĞLA
    'Muğla Sıtkı Koçman Üniversitesi': 'Muğla',
    
    // TUNCELİ
    'Munzur Üniversitesi': 'Tunceli',
    
    // MUŞ
    'Muş Alparslan Üniversitesi': 'Muş',
    
    // NEVŞEHİR
    'Nevşehir Hacı Bektaş Veli Üniversitesi': 'Nevşehir',
    
    // NİĞDE
    'Niğde Ömer Halisdemir Üniversitesi': 'Niğde',
    
    // SAMSUN
    'Ondokuz Mayıs Üniversitesi': 'Samsun',
    'Samsun Üniversitesi': 'Samsun',
    
    // ORDU
    'Ordu Üniversitesi': 'Ordu',
    
    // OSMANİYE
    'Osmaniye Korkut Ata Üniversitesi': 'Osmaniye',
    
    // DENİZLİ
    'Pamukkale Üniversitesi': 'Denizli',
    
    // RİZE
    'Recep Tayyip Erdoğan Üniversitesi': 'Rize',
    
    // SAKARYA
    'Sakarya Üniversitesi': 'Sakarya',
    'Sakarya Uygulamalı Bilimler Üniversitesi': 'Sakarya',
    
    // SİİRT
    'Siirt Üniversitesi': 'Siirt',
    
    // SİNOP
    'Sinop Üniversitesi': 'Sinop',
    
    // SİVAS
    'Sivas Cumhuriyet Üniversitesi': 'Sivas',
    'Cumhuriyet Üniversitesi': 'Sivas',
    'Sivas Bilim ve Teknoloji Üniversitesi': 'Sivas',
    
    // ŞIRNAK
    'Şırnak Üniversitesi': 'Şırnak',
    
    // TEKİRDAĞ
    'Tekirdağ Namık Kemal Üniversitesi': 'Tekirdağ',
    'Namık Kemal Üniversitesi': 'Tekirdağ',
    
    // TOKAT
    'Tokat Gaziosmanpaşa Üniversitesi': 'Tokat',
    
    // EDİRNE
    'Trakya Üniversitesi': 'Edirne',
    
    // UŞAK
    'Uşak Üniversitesi': 'Uşak',
    
    // VAN
    'Van Yüzüncü Yıl Üniversitesi': 'Van',
    
    // YALOVA
    'Yalova Üniversitesi': 'Yalova',
    
    // YOZGAT
    'Yozgat Bozok Üniversitesi': 'Yozgat',
    
    // ZONGULDAK
    'Zonguldak Bülent Ecevit Üniversitesi': 'Zonguldak',
    'Bülent Ecevit Üniversitesi': 'Zonguldak',
    
    // ============ VAKIF ÜNİVERSİTELERİ ============
    
    // İSTANBUL
    'Acıbadem Üniversitesi': 'İstanbul',
    'Altınbaş Üniversitesi': 'İstanbul',
    'Bahçeşehir Üniversitesi': 'İstanbul',
    'Beykent Üniversitesi': 'İstanbul',
    'Beykoz Üniversitesi': 'İstanbul',
    'Bezmiâlem Vakıf Üniversitesi': 'İstanbul',
    'Biruni Üniversitesi': 'İstanbul',
    'Doğuş Üniversitesi': 'İstanbul',
    'Fatih Sultan Mehmet Vakıf Üniversitesi': 'İstanbul',
    'Fenerbahçe Üniversitesi': 'İstanbul',
    'Haliç Üniversitesi': 'İstanbul',
    'Işık Üniversitesi': 'İstanbul',
    'İbn Haldun Üniversitesi': 'İstanbul',
    'İstanbul 29 Mayıs Üniversitesi': 'İstanbul',
    'İstanbul Arel Üniversitesi': 'İstanbul',
    'İstanbul Atlas Üniversitesi': 'İstanbul',
    'İstanbul Aydın Üniversitesi': 'İstanbul',
    'İstanbul Bilgi Üniversitesi': 'İstanbul',
    'İstanbul Esenyurt Üniversitesi': 'İstanbul',
    'İstanbul Galata Üniversitesi': 'İstanbul',
    'İstanbul Gedik Üniversitesi': 'İstanbul',
    'İstanbul Gelişim Üniversitesi': 'İstanbul',
    'İstanbul Kent Üniversitesi': 'İstanbul',
    'İstanbul Kültür Üniversitesi': 'İstanbul',
    'İstanbul Medipol Üniversitesi': 'İstanbul',
    'İstanbul Okan Üniversitesi': 'İstanbul',
    'İstanbul Rumeli Üniversitesi': 'İstanbul',
    'İstanbul Sabahattin Zaim Üniversitesi': 'İstanbul',
    'İstanbul Ticaret Üniversitesi': 'İstanbul',
    'İstanbul Topkapı Üniversitesi': 'İstanbul',
    'İstinye Üniversitesi': 'İstanbul',
    'Kadir Has Üniversitesi': 'İstanbul',
    'Koç Üniversitesi': 'İstanbul',
    'Maltepe Üniversitesi': 'İstanbul',
    'MEF Üniversitesi': 'İstanbul',
    'Nişantaşı Üniversitesi': 'İstanbul',
    'Özyeğin Üniversitesi': 'İstanbul',
    'Piri Reis Üniversitesi': 'İstanbul',
    'Sabancı Üniversitesi': 'İstanbul',
    'Üsküdar Üniversitesi': 'İstanbul',
    'Yeditepe Üniversitesi': 'İstanbul',
    'Yeni Yüzyıl Üniversitesi': 'İstanbul',
    
    // ANTALYA
    'Antalya Bilim Üniversitesi': 'Antalya',
    
    // ANKARA
    'Atılım Üniversitesi': 'Ankara',
    'Başkent Üniversitesi': 'Ankara',
    'Çankaya Üniversitesi': 'Ankara',
    'Ihsan Doğramacı Bilkent Üniversitesi': 'Ankara',
    'Bilkent Üniversitesi': 'Ankara',
    'Lokman Hekim Üniversitesi': 'Ankara',
    'OSTİM Teknik Üniversitesi': 'Ankara',
    'TED Üniversitesi': 'Ankara',
    'TOBB Ekonomi ve Teknoloji Üniversitesi': 'Ankara',
    'Türk Hava Kurumu Üniversitesi': 'Ankara',
    'Ufuk Üniversitesi': 'Ankara',
    
    // MERSİN
    'Çağ Üniversitesi': 'Mersin',
    
    // GAZİANTEP
    'Hasan Kalyoncu Üniversitesi': 'Gaziantep',
    'Sanko Üniversitesi': 'Gaziantep',
    
    // İZMİR
    'İzmir Ekonomi Üniversitesi': 'İzmir',
    'İzmir Tınaztepe Üniversitesi': 'İzmir',
    'Yaşar Üniversitesi': 'İzmir',
    
    // KAYSERİ
    'Nuh Naci Yazgan Üniversitesi': 'Kayseri',
  };

  /// Üniversite adına göre şehir döndür
  /// 
  /// Örnek:
  /// ```dart
  /// final city = UniversityData.getCityForUniversity('Yaşar Üniversitesi'); // 'İzmir'
  /// ```
  /// 
  /// Eğer üniversite bulunamazsa `null` döner.
  static String? getCityForUniversity(String? universityName) {
    if (universityName == null || universityName.isEmpty) return null;
    return universityCities[universityName];
  }

  /// Tüm şehirlerin benzersiz listesini döndür (Alfabetik sıralı)
  static List<String> getAllCities() {
    final cities = universityCities.values.toSet().toList();
    cities.sort();
    return cities;
  }

  /// Belirli bir şehirdeki tüm üniversiteleri döndür
  /// 
  /// Örnek:
  /// ```dart
  /// final izmirUnis = UniversityData.getUniversitiesInCity('İzmir');
  /// // ['Ege Üniversitesi', 'Dokuz Eylül Üniversitesi', ...]
  /// ```
  static List<String> getUniversitiesInCity(String city) {
    return universityCities.entries
        .where((entry) => entry.value == city)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Tüm üniversiteleri alfabetik sıralı döndür (şehir seçilmediğinde kullanılır)
  static List<String> getAllUniversitiesSorted() {
    final list = universityCities.keys.toList();
    list.sort();
    return list;
  }

  /// Bir üniversitenin kayıtlı olup olmadığını kontrol et
  static bool isRegisteredUniversity(String? universityName) {
    if (universityName == null || universityName.isEmpty) return false;
    return universityCities.containsKey(universityName);
  }

  /// Tüm benzersiz şehirleri al (Öncelikli sıralama ile)
  /// İlk 3: İzmir, İstanbul, Ankara
  /// Geri kalan: Alfabetik sıralı
  static List<String> getAllCitiesSorted() {
    // 1. Tüm benzersiz şehirleri çıkar
    final allCities = universityCities.values.toSet().toList();
    
    // 2. Popüler şehirler (sabit sıra)
    const priorityCities = ['İzmir', 'İstanbul', 'Ankara'];
    
    // 3. Geri kalan şehirleri alfabetik sırala
    final otherCities = allCities
        .where((city) => !priorityCities.contains(city))
        .toList()
      ..sort();
    
    // 4. Birleştir: Önce öncelikli, sonra alfabetik
    return [...priorityCities, ...otherCities];
  }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Algorun';

  @override
  String get homeTagline => 'Algoritmayı kur.\nAsla yazma.';

  @override
  String get homeProgress => 'İLERLEME';

  @override
  String homeSolvedCount(int solved, int total) {
    return '$total bulmacadan $solved tanesi çözüldü';
  }

  @override
  String homeLastPlayed(String puzzle, String world) {
    return 'Son oynanan: $puzzle · $world';
  }

  @override
  String get homeContinue => 'DEVAM ET';

  @override
  String get homeWorlds => 'DÜNYALAR';

  @override
  String get homeEnter => 'BAŞLA';

  @override
  String get homeSettings => 'Ayarlar';

  @override
  String get homeGuide => 'Blok Rehberi';

  @override
  String get homeHowToPlay => 'Yeni misin? Nasıl oynanır, gör';

  @override
  String get worldsTitle => 'Dünyalar';

  @override
  String worldTeaches(String concepts) {
    return 'Öğrettikleri: $concepts';
  }

  @override
  String get tagCurrent => 'ŞU AN';

  @override
  String get worldNoPuzzles => 'Henüz bulmaca yok';

  @override
  String get worldSolvedOne => 'Çözüldü';

  @override
  String worldAllSolved(int total) {
    return '$total bulmacanın hepsi çözüldü';
  }

  @override
  String worldProgress(int solved, int total) {
    return '$total bulmacadan $solved çözüldü';
  }

  @override
  String lockedLearnFirst(String concepts) {
    return 'Kilitli — önce öğren: $concepts';
  }

  @override
  String get locked => 'Kilitli';

  @override
  String get stateCompleted => 'Tamamlandı';

  @override
  String get stateOpen => 'Açık';

  @override
  String get puzzlesTitle => 'Bulmacalar';

  @override
  String worldHeading(String index, String title) {
    return '$index · $title';
  }

  @override
  String puzzleListHeader(int solved, int total, String concepts) {
    return '$total bulmacadan $solved çözüldü · öğrettikleri: $concepts';
  }

  @override
  String tierLabel(int tier) {
    return 'Seviye $tier';
  }

  @override
  String tierWithMode(int tier, String mode) {
    return 'Seviye $tier · $mode';
  }

  @override
  String get unknownWorld => 'Bilinmeyen dünya.';

  @override
  String get statusNotStarted => 'Başlanmadı';

  @override
  String get statusInProgress => 'Devam ediyor';

  @override
  String statusInProgressLastRun(String result) {
    return 'Devam ediyor · son çalıştırma: $result';
  }

  @override
  String statusInProgressLastRunEdited(String result) {
    return 'Devam ediyor · son çalıştırma: $result, sonra düzenlendi';
  }

  @override
  String get statusSolved => 'Çözüldü';

  @override
  String statusSolvedBest(String steps, int blocks) {
    return 'Çözüldü · en iyi $steps adım · $blocks blok';
  }

  @override
  String get modeBuild => 'kur';

  @override
  String get modeBudget => 'bütçe';

  @override
  String get modeOptimize => 'optimize et';

  @override
  String get modeEdge => 'uç durum';

  @override
  String get modeRestricted => 'kısıtlı';

  @override
  String get modeOther => 'görev';

  @override
  String get puzzleFallbackTitle => 'Bulmaca';

  @override
  String get puzzleCouldNotOpen => 'Bu bulmaca açılamadı.';

  @override
  String get puzzleOpening => 'Bulmaca açılıyor…';

  @override
  String get puzzleLocked => 'Bu bulmaca kilitli.';

  @override
  String puzzleLockedLearn(String concepts) {
    return 'Bu bulmaca kilitli. Şunları öğrendiğinde açılır: $concepts.';
  }

  @override
  String get puzzleLockedHow =>
      'Bir kavram, onu öğreten dünyadaki her bulmaca çözülünce öğrenilmiş olur.';

  @override
  String get back => 'GERİ';

  @override
  String get puzzleChangedNotice =>
      'Bu bulmaca son oynadığından beri değişti. Programın korundu; ÇALIŞTIR neyin güncelleneceğini gösterir.';

  @override
  String get solved => 'Çözüldü';

  @override
  String get programOptions => 'Program seçenekleri';

  @override
  String get foldAll => 'Tüm blokları katla';

  @override
  String get unfoldAll => 'Tüm blokları aç';

  @override
  String get clearProgram => 'Programı temizle';

  @override
  String get solvedLine =>
      'Çözüldü. Geliştirmeye devam et ya da sıradakini dene.';

  @override
  String get loadBest => 'En iyi çözümü yükle';

  @override
  String get bestButton => 'EN İYİ';

  @override
  String get bestLoaded =>
      'En iyi çözümün yüklendi. GERİ AL önceki programını geri getirir.';

  @override
  String get programCleared => 'Program temizlendi. GERİ AL onu geri getirir.';

  @override
  String get blockNeedsAttention => 'Bu blokla ilgilenmen gerekiyor.';

  @override
  String get brief => 'GÖREV';

  @override
  String briefTier(int tier) {
    return 'SEVİYE $tier';
  }

  @override
  String briefTierMode(int tier, String mode) {
    return 'SEVİYE $tier · $mode';
  }

  @override
  String get ioInputs => 'GİRDİLER';

  @override
  String get ioReturns => 'DÖNDÜRÜR';

  @override
  String get ioFunctions => 'YAZACAĞIN FONKSİYONLAR';

  @override
  String get hints => 'İPUÇLARI';

  @override
  String showHint(int n) {
    return '$n. İPUCU';
  }

  @override
  String get noMoreHints => 'BAŞKA İPUCU YOK';

  @override
  String get hintsIntro =>
      'İpuçları fikirden yönteme doğru, birer birer gelir. Sayılırlar ama hiçbir şeye mal olmazlar.';

  @override
  String get givens => 'VERİLENLER';

  @override
  String get variables => 'DEĞİŞKENLER';

  @override
  String insideFunction(String name) {
    return '$name İÇİNDE';
  }

  @override
  String get variablesNote =>
      'Bu adları bulmaca sağlar; önce bir yuvaya, sonra bir ada dokun.';

  @override
  String get program => 'PROGRAM';

  @override
  String get tapSlotThenName => 'Önce bir değer yuvasına, sonra bir ada dokun.';

  @override
  String get nameDoesNotFit => 'Bu ad bu yuvaya uymuyor.';

  @override
  String get openGuide => 'Blok rehberi';

  @override
  String get typeNumber => 'sayı';

  @override
  String get typeBool => 'evet / hayır';

  @override
  String get typeText => 'metin';

  @override
  String get typeNothing => 'hiçbir şey';

  @override
  String get typeValue => 'değer';

  @override
  String get typeListNode => 'zincir halkası';

  @override
  String get typeTreeNode => 'ağaç düğümü';

  @override
  String get typeGraph => 'çizge';

  @override
  String get itemNumber => 'sayı';

  @override
  String get itemBool => 'evet / hayır';

  @override
  String get itemText => 'metin';

  @override
  String get itemValue => 'değer';

  @override
  String get itemList => 'liste';

  @override
  String get itemListNode => 'zincir halkası';

  @override
  String get itemTreeNode => 'ağaç düğümü';

  @override
  String get itemGraph => 'çizge';

  @override
  String get itemOther => 'koleksiyon';

  @override
  String typeListOf(String item) {
    return '$item listesi';
  }

  @override
  String typeSetOf(String item) {
    return '$item kümesi';
  }

  @override
  String typeStackOf(String item) {
    return '$item yığını';
  }

  @override
  String typeQueueOf(String item) {
    return '$item kuyruğu';
  }

  @override
  String typeHeapOf(String item) {
    return '$item öncelik kuyruğu';
  }

  @override
  String typeDequeOf(String item) {
    return '$item çift uçlu kuyruğu';
  }

  @override
  String typeMapOf(String key, String value) {
    return '$key → $value eşlemesi';
  }

  @override
  String typeMaybe(String type) {
    return '$type ya da NOTHING';
  }

  @override
  String get typeCollection => 'koleksiyon';

  @override
  String get dismiss => 'Kapat';

  @override
  String get selected => 'SEÇİLİ';

  @override
  String blocksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blok',
    );
    return '$_temp0';
  }

  @override
  String selectionTitle(String label, String blocks) {
    return '$label · $blocks';
  }

  @override
  String get actionUp => 'YUKARI';

  @override
  String get actionDown => 'AŞAĞI';

  @override
  String get actionOut => 'DIŞARI';

  @override
  String get actionIn => 'İÇERİ';

  @override
  String get actionCopy => 'KOPYALA';

  @override
  String get actionDelete => 'SİL';

  @override
  String get actionReplace => 'DEĞİŞTİR';

  @override
  String get moveUp => 'Yukarı taşı';

  @override
  String get moveDown => 'Aşağı taşı';

  @override
  String get moveOut => 'Çevresindeki bloğun dışına taşı';

  @override
  String get moveIn => 'Üstteki bloğun içine taşı';

  @override
  String get duplicate => 'Çoğalt';

  @override
  String get delete => 'Sil';

  @override
  String deleteWithInside(String blocks) {
    return 'Onu ve içindeki $blocks bloğu sil';
  }

  @override
  String get replaceValue => 'Bu değeri değiştir';

  @override
  String get done => 'Bitti';

  @override
  String get undo => 'Geri al';

  @override
  String get redo => 'Yinele';

  @override
  String blockCountWithMax(int count, int max) {
    return '$count / $max blok';
  }

  @override
  String blockCountSemantics(int count, int max) {
    return '$max bloktan $count tanesi';
  }

  @override
  String get overBudgetSuffix => ', bütçenin üstünde';

  @override
  String get savedOnDevice => 'Cihazda kayıtlı';

  @override
  String get practiceNotSaved => 'Alıştırma · kaydedilmez';

  @override
  String get run => 'ÇALIŞTIR';

  @override
  String get running => 'ÇALIŞIYOR';

  @override
  String noticeRemoved(String label) {
    return '$label silindi. GERİ AL onu geri getirir.';
  }

  @override
  String noticeRemovedWithInside(String label, String blocks) {
    return '$label ve içindeki $blocks silindi. GERİ AL onları geri getirir.';
  }

  @override
  String noticeCopied(String label) {
    return '$label kopyalandı.';
  }

  @override
  String noticeCopiedWithInside(String label, String blocks) {
    return '$label, içindeki $blocks ile birlikte kopyalandı.';
  }

  @override
  String get noticeTapSlotFirst => 'Önce bir değer yuvasına dokun.';

  @override
  String get noticePieceDoesNotFit => 'Bu parça buraya uymuyor.';

  @override
  String get chooseAPiece => 'Bir parça seç';

  @override
  String pickerFor(String target) {
    return 'Yer: $target. Yalnızca buraya uyan parçalar listelenir.';
  }

  @override
  String get close => 'Kapat';

  @override
  String get nothingFits => 'Bu bulmacada buraya uyan bir şey yok.';

  @override
  String get targetProgram => 'program';

  @override
  String get targetSlot => 'bu yuva';

  @override
  String get targetElse => 'ELSE';

  @override
  String targetThenOf(String block) {
    return '$block bloğunun THEN kısmı';
  }

  @override
  String targetDoOf(String block) {
    return '$block bloğunun DO kısmı';
  }

  @override
  String targetElseOf(String block) {
    return '$block bloğunun ELSE kısmı';
  }

  @override
  String targetCaptionOf(String caption, String block) {
    return '$block bloğunun $caption yuvası';
  }

  @override
  String get captionCondition => 'koşul';

  @override
  String get captionNumber => 'sayı';

  @override
  String get captionList => 'liste';

  @override
  String get captionValue => 'değer';

  @override
  String get captionMap => 'eşleme';

  @override
  String get captionSet => 'küme';

  @override
  String get captionStack => 'yığın';

  @override
  String get captionQueue => 'kuyruk';

  @override
  String get captionHeap => 'öncelik kuyruğu';

  @override
  String get captionKey => 'anahtar';

  @override
  String get captionNode => 'düğüm';

  @override
  String get captionGraph => 'çizge';

  @override
  String get captionInstruction => 'komut';

  @override
  String get captionElse => 'else';

  @override
  String emptySlot(String caption) {
    return 'Boş $caption yuvası';
  }

  @override
  String get catAll => 'TÜMÜ';

  @override
  String get catControl => 'KONTROL';

  @override
  String get catValues => 'DEĞERLER';

  @override
  String get catLogic => 'MANTIK';

  @override
  String get catMath => 'MATEMATİK';

  @override
  String get catLists => 'LİSTELER';

  @override
  String get catStructure => 'YAPILAR';

  @override
  String get paletteBlocks => 'BLOKLAR';

  @override
  String get addStep => 'adım ekle';

  @override
  String get emptyProgram =>
      'Programın boş. İlk komutu yerleştirmek için dokun.';

  @override
  String get addElse => 'ELSE EKLE';

  @override
  String get removeElse => 'ELSE kısmını kaldır';

  @override
  String get collapse => 'Katla';

  @override
  String get expand => 'Aç';

  @override
  String get foldedEmpty => 'Katlı · boş';

  @override
  String foldedInside(String blocks) {
    return 'Katlı · içinde $blocks';
  }

  @override
  String variableChange(String name) {
    return 'Değişken $name, değiştir';
  }

  @override
  String get namePlaceholder => 'ad';

  @override
  String get itemPlaceholder => 'öğe';

  @override
  String get chooseName => 'Bir ad seç';

  @override
  String get namesFromPuzzle => 'Adlar bulmacadan gelir; yazman gerekmez.';

  @override
  String get padDone => 'TAMAM';

  @override
  String get padClear => 'TEMİZLE';

  @override
  String get padSelectedHint => 'Yazdığın rakamlar bu sayının yerine geçer';

  @override
  String get padEditHint => 'Hepsini seçmek için sayıya dokun';

  @override
  String get padEmpty => 'Bir sayı yaz';

  @override
  String get padNegative => 'negatif';

  @override
  String get changeSign => 'İşareti değiştir';

  @override
  String get deleteDigit => 'Son rakamı sil';

  @override
  String get clearNumber => 'Sayıyı temizle';

  @override
  String padValueSemantics(String value) {
    return 'Sayı $value';
  }

  @override
  String get resultTitle => 'Sonuç';

  @override
  String get noResult => 'Sonuç yok.';

  @override
  String get verdictCorrect => 'DOĞRU';

  @override
  String get verdictWrongAnswer => 'YANLIŞ CEVAP';

  @override
  String get verdictRuntimeError => 'ÇALIŞMA HATASI';

  @override
  String get verdictOperationLimit => 'ADIM SINIRI';

  @override
  String get verdictTimeLimit => 'ZAMAN SINIRI';

  @override
  String get verdictMemoryLimit => 'BELLEK SINIRI';

  @override
  String get verdictDepthLimit => 'DERİNLİK SINIRI';

  @override
  String get verdictInvalidProgram => 'GEÇERSİZ PROGRAM';

  @override
  String get kindCorrect => 'doğru';

  @override
  String get kindWrongAnswer => 'yanlış cevap';

  @override
  String get kindRuntimeError => 'çalışma hatası';

  @override
  String get kindOperationLimit => 'adım sınırı';

  @override
  String get kindTimeLimit => 'zaman sınırı';

  @override
  String get kindMemoryLimit => 'bellek sınırı';

  @override
  String get kindDepthLimit => 'derinlik sınırı';

  @override
  String get kindInvalidProgram => 'geçersiz program';

  @override
  String get meaningCorrect =>
      'Her vaka doğru sonuçlandı, her bütçenin içinde.';

  @override
  String get meaningWrongAnswer =>
      'Program bitti, ama en az bir cevap beklenen değil.';

  @override
  String get meaningRuntimeError =>
      'Program yerine getiremediği bir komutta durdu.';

  @override
  String get meaningOperationLimit =>
      'Program bütçenin izin verdiğinden fazla adıma ihtiyaç duydu.';

  @override
  String get meaningTimeLimit => 'Programın süresi doldu.';

  @override
  String get meaningMemoryLimit =>
      'Program listelerinde ve eşlemelerinde bütçenin izin verdiğinden fazla değer tuttu.';

  @override
  String get meaningDepthLimit =>
      'Program bütçenin izin verdiğinden daha derine indi.';

  @override
  String get meaningInvalidProgram =>
      'Program henüz çalışamaz. Aşağıda listelenenleri düzelt.';

  @override
  String get progressSection => 'İLERLEME';

  @override
  String get progressSolved => 'Bulmaca çözüldü.';

  @override
  String progressNewBest(String metrics) {
    return 'Yeni en iyi: $metrics.';
  }

  @override
  String progressNowOpen(String worlds) {
    return 'Artık açık: $worlds.';
  }

  @override
  String get bestSteps => 'en az adım';

  @override
  String get bestMemory => 'en az bellek';

  @override
  String get bestDepth => 'en az derinlik';

  @override
  String get bestBlocks => 'en az blok';

  @override
  String get bestHints => 'en az ipucu';

  @override
  String get whatToFix => 'DÜZELTİLECEKLER';

  @override
  String get cases => 'VAKALAR';

  @override
  String get hidden => 'GİZLİ';

  @override
  String hiddenPassed(int passed, int total) {
    return '$total gizli vakadan $passed tanesi geçti.';
  }

  @override
  String get whatItCost => 'MALİYET';

  @override
  String get costUsed => 'KULLANILAN';

  @override
  String get costBudget => 'BÜTÇE';

  @override
  String get costSteps => 'Adımlar';

  @override
  String get costMemory => 'Bellek hücreleri';

  @override
  String get costDepth => 'Derinlik';

  @override
  String get costBlocks => 'Bloklar';

  @override
  String get costHints => 'İpuçları';

  @override
  String hintsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ipucu',
    );
    return '$_temp0';
  }

  @override
  String costRowSemantics(String label, String used, String budget) {
    return '$label: $used kullanıldı, bütçe $budget';
  }

  @override
  String stoppedAfterStep(int step) {
    return '$step. adımdan sonra durdu.';
  }

  @override
  String get hiddenNotShown => 'Gizli test girdileri ve cevapları gösterilmez.';

  @override
  String nextPuzzle(String title) {
    return 'SIRADAKİ: $title';
  }

  @override
  String get backToPuzzle => 'BULMACAYA DÖN';

  @override
  String get casePassed => 'geçti';

  @override
  String get caseGiven => 'verilen';

  @override
  String get caseExpected => 'beklenen';

  @override
  String get caseYouGave => 'senin verdiğin';

  @override
  String perfCorrectButOver(String measured, String budget) {
    return 'Sonuç doğru, ama bu çözüm çok fazla işlem kullanıyor: $budget bütçesine karşı $measured.';
  }

  @override
  String perfStillRunning(String measured, String budget) {
    return 'Biten her vaka doğru sonuçlandı, ama bu çözüm çok fazla işlem kullanıyor: $measured işlemden sonra hâlâ çalışıyordu ve bütçe $budget.';
  }

  @override
  String perfWrongAndOver(String ops, String budget) {
    return 'Bu çözüm çok fazla işlem kullanıyor ($budget bütçesine karşı $ops) ve her cevap da doğru değil.';
  }

  @override
  String perfMoreThan(String count) {
    return '$count işlemden fazla';
  }

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get showBriefSetting => 'Bulmaca açılınca görevi göster';

  @override
  String get privacyNote =>
      'İlerlemen, programların ve en iyi sonuçların yalnızca bu cihaza kaydedilir. Hesap yoktur ve hiçbir şey yüklenmez.';

  @override
  String get webStorageNote =>
      'Web tarayıcısında ilerleme o tarayıcıda, bu adres için saklanır. Sitenin verilerini silersen ya da başka bir tarayıcı kullanırsan baştan başlarsın.';

  @override
  String get saveFileSection => 'KAYIT DOSYASI';

  @override
  String get saveFileNote =>
      'Bu tarayıcının verileri silinirse ilerlemen de gider. Ara sıra kayıt dosyasını indir; devam etmek için onu buraya ya da başka bir tarayıcıya yükle.';

  @override
  String get saveFileDownload => 'Kaydı indir';

  @override
  String get saveFileLoad => 'Kaydı yükle';

  @override
  String get saveFileDownloaded => 'Kayıt dosyası indirildi.';

  @override
  String get saveFileLoadTitle => 'Kayıt dosyası yüklensin mi?';

  @override
  String get saveFileLoadBody =>
      'Dosyadaki ilerleme, bu tarayıcıdaki ilerlemenin yerini alır.';

  @override
  String get saveFileChoose => 'Dosya seç';

  @override
  String get saveFileLoadFailed =>
      'Bu dosya bir Algorun kaydı değil. Hiçbir şey değişmedi.';

  @override
  String saveFileLoaded(int count) {
    return 'Kayıt yüklendi: $count çözülmüş bulmaca.';
  }

  @override
  String get resetProgress => 'İlerlemeyi sıfırla';

  @override
  String get resetConfirmTitle => 'İlerleme sıfırlansın mı?';

  @override
  String get resetConfirmBody =>
      'Bu cihazdaki her çözülmüş bulmaca, kayıtlı program ve en iyi sonuç silinir. Bu geri alınamaz.';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get reset => 'Sıfırla';

  @override
  String get platformNote =>
      'Birincil hedef Android. Motor kodu saf Dart ve Flutter içe aktarmaz.';

  @override
  String get languageSection => 'DİL';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageNote =>
      'IF, WHILE ve RETURN gibi blok adları her dilde İngilizce kalır. Blok rehberi her birini açıklar.';

  @override
  String get languageSelected => 'seçili';

  @override
  String get themeSection => 'GÖRÜNÜM';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeNote => 'Sistem, cihazının açık ya da koyu ayarını izler.';

  @override
  String get developerSection => 'GELİŞTİRİCİ';

  @override
  String get developerNote =>
      'Yalnızca hata ayıklama derlemelerinde. Stres probu, editörü telefonda denemek için uzun ve derin bir program açar; kaydedilmez ve kampanyanın parçası değildir.';

  @override
  String get openStressProbe => 'Editör stres probunu aç';

  @override
  String versionLine(String version) {
    return 'Sürüm $version';
  }

  @override
  String get guideTitle => 'Blok Rehberi';

  @override
  String get guideTabBasics => 'Nasıl oynanır';

  @override
  String get guideTabConcepts => 'Kavramlar';

  @override
  String get guideTabBlocks => 'Bloklar';

  @override
  String get guideInThisPuzzle => 'BU BULMACADA';

  @override
  String get guideAllBlocks => 'TÜM BLOKLAR';

  @override
  String get guideExample => 'Örnek';

  @override
  String get guideKeywordNote =>
      'Blok adları İngilizce kalır. Her kart adı, Türkçe ve İngilizce anlamını ve küçük bir örneği verir.';

  @override
  String get guideBasics1Title => 'Görevi oku';

  @override
  String get guideBasics1 =>
      'Görev hikâyeyi ve neyin döndürüleceğini anlatır. GİRDİLER bulmacanın sana verdiklerini listeler; DÖNDÜRÜR programının ne geri vermesi gerektiğini söyler.';

  @override
  String get guideBasics2Title => 'Komutları yerleştir';

  @override
  String get guideBasics2 =>
      'adım ekle\'ye dokun ve bir parça seç. Seçici yalnızca dokunduğun yere uyan parçaları listeler; hiç kod yazmazsın.';

  @override
  String get guideBasics3Title => 'Yuvaları doldur';

  @override
  String get guideBasics3 =>
      'Kesikli çizgili bir yuva henüz boştur. Bir değer takmak için dokun: VERİLENLER ya da DEĞİŞKENLER\'den bir ad, bir sayı ya da bir hesaplama.';

  @override
  String get guideBasics4Title => 'Düzenle';

  @override
  String get guideBasics4 =>
      'Bir bloğu seçmek için dokun, sonra taşı, kopyala ya da sil. Her değişiklik geri alınabilir. Taslağı görmek için uzun blokları katla.';

  @override
  String get guideBasics5Title => 'Çalıştır';

  @override
  String get guideBasics5 =>
      'ÇALIŞTIR programını görünen vakalarda ve gizli vakalarda dener. Gizli vakalar yalnızca kaçının geçtiğini gösterir. Bazı bulmacaların bir adım bütçesi de vardır: doğru ama yavaş bir program yetmez.';

  @override
  String get guideBasics6Title => 'İpuçları ve ilerleme';

  @override
  String get guideBasics6 =>
      'İpuçları birer birer gelir. Çözmene engel olmaz; sonuç yalnızca kaç tane kullandığını sayar. Bir dünyanın tüm bulmacalarını çözmek onun kavramlarını öğretir ve sonraki dünyaları açar.';

  @override
  String get engineNotReadyToRun => 'Bu program henüz çalışmaya hazır değil.';

  @override
  String get engineTheCanvasIsEmpty => 'Program boş.';

  @override
  String get engineUnknownBlock => 'Bilinmeyen blok.';

  @override
  String get engineAStackPointsAtAMissingBlock =>
      'Bir komut dizisi eksik bir bloğa bağlı.';

  @override
  String get engineThisProgramIsNotPutTogetherCorrectly =>
      'Bu program doğru birleştirilmemiş.';

  @override
  String get engineOnlyAnElseBranchFitsHere =>
      'Buraya yalnızca bir ELSE dalı uyar.';

  @override
  String get engineThisPieceCannotBeUsedYet => 'Bu parça henüz kullanılamaz.';

  @override
  String get engineThisSpotNeedsAnInstructionNotA =>
      'Buraya değer değil, bir komut gerekir.';

  @override
  String get engineAConnectionPointsAtAMissingBlock =>
      'Bir bağlantı eksik bir bloğu gösteriyor.';

  @override
  String get engineChooseAName => 'Bir ad seç.';

  @override
  String get engineThisBlockNeedsAList => 'Bu blok bir liste bekliyor.';

  @override
  String get engineThisVariableIsNotDefined => 'Bu değişken tanımlı değil.';

  @override
  String get engineThisVariableIsNotANumber => 'Bu değişken bir sayı değil.';

  @override
  String get engineThisPieceDoesNotFitHere => 'Bu parça buraya uymuyor.';

  @override
  String get engineThisBlockNeedsANumber => 'Bu blok bir sayı bekliyor.';

  @override
  String get engineThisSpotNeedsAValueNotA =>
      'Buraya tam bir komut değil, bir değer gerekir.';

  @override
  String get engineThisBlockNeedsACondition => 'Bu blok bir koşul bekliyor.';

  @override
  String get engineThisBlockNeedsAMap => 'Bu blok bir eşleme bekliyor.';

  @override
  String get engineThisBlockNeedsASet => 'Bu blok bir küme bekliyor.';

  @override
  String get engineThisBlockNeedsAStack => 'Bu blok bir yığın bekliyor.';

  @override
  String get engineThisBlockNeedsAQueue => 'Bu blok bir kuyruk bekliyor.';

  @override
  String get engineThisBlockNeedsAHeap =>
      'Bu blok bir öncelik kuyruğu bekliyor.';

  @override
  String get engineThisBlockNeedsAValue => 'Bu blok bir değer bekliyor.';

  @override
  String get engineThisBlockNeedsAKey => 'Bu blok bir anahtar bekliyor.';

  @override
  String get engineThisBlockNeedsANode => 'Bu blok bir düğüm bekliyor.';

  @override
  String get engineThisBlockNeedsAGraph => 'Bu blok bir çizge bekliyor.';

  @override
  String get engineThatBlockAlreadyExists => 'Bu blok zaten var.';

  @override
  String get engineThatBlockIsGone => 'Bu blok artık yok.';

  @override
  String get engineThisBlockIsNotAttached => 'Bu blok hiçbir yere bağlı değil.';

  @override
  String get engineThatNameIsAlreadyInUse => 'Bu ad zaten kullanılıyor.';

  @override
  String get engineThisValueMayBeEmptyHereCheck =>
      'Bu değer burada boş (NOTHING) olabilir. Önce boş olmadığını kontrol et.';

  @override
  String get engineCheckAValueThatMayBeEmpty =>
      'NOTHING\'in kendisini değil, boş olabilecek bir değeri kontrol et.';

  @override
  String get engineThisValueIsNeverEmptyHereSo =>
      'Bu değer burada hiçbir zaman boş değil; kontrol edilecek bir şey yok.';

  @override
  String get engineSomethingIsAlreadyPluggedInHere =>
      'Buraya zaten bir şey takılı.';

  @override
  String get engineThisBlockIsAttachedInTwoPlaces =>
      'Bu blok iki yere birden bağlı.';

  @override
  String get engineThisWouldLoopBackOnItself =>
      'Bu, bloğu kendi içine bağlardı.';

  @override
  String get engineThesePiecesDoNotAttachThatWay =>
      'Bu parçalar bu şekilde birleşmez.';

  @override
  String get engineThisBlockIsAlreadyAttachedSomewhereElse =>
      'Bu blok zaten başka bir yere bağlı.';

  @override
  String get engineThisBlockIsAlreadyInThatStack =>
      'Bu blok zaten o komut dizisinde.';

  @override
  String get engineThatStackPositionDoesNotExist =>
      'Komut dizisinde böyle bir konum yok.';

  @override
  String get engineBreakAndContinueOnlyWorkInsideA =>
      'BREAK ve CONTINUE yalnızca bir döngünün içinde çalışır.';

  @override
  String get engineThisPuzzleDoesNotExposeAnyBlocks =>
      'Bu bulmaca hiçbir blok sunmuyor.';

  @override
  String get engineThisPuzzleDoesNotIncludeThatBlock =>
      'Bu bulmacada o blok yok.';

  @override
  String get engineThisProgramHasNoStartingPoint =>
      'Bu programın başlangıç noktası yok.';

  @override
  String get engineThisProgramWentTooManyLevelsDeep =>
      'Bu program çok fazla iç içe seviyeye indi.';

  @override
  String get engineThisBlockOnlyWorksInsideALoop =>
      'Bu blok yalnızca bir döngünün içinde çalışır.';

  @override
  String get engineThisLoopWouldNeverFinish => 'Bu döngü hiç bitmezdi.';

  @override
  String get engineThisValueCannotBeUsedHere => 'Bu değer burada kullanılamaz.';

  @override
  String get engineThisNameHasNoValueYet => 'Bu adın henüz bir değeri yok.';

  @override
  String get engineYouCannotDivideByZero => 'Sıfıra bölünemez.';

  @override
  String get engineThisNumberIsTooBig => 'Bu sayı çok büyük.';

  @override
  String get engineThisCallIsMissingAValue => 'Bu çağrıda bir değer eksik.';

  @override
  String get engineThisBlockIsMissingAValue => 'Bu blokta bir değer eksik.';

  @override
  String get engineThisListGotTooBig => 'Bu liste çok büyüdü.';

  @override
  String get engineThisMapGotTooBig => 'Bu eşleme çok büyüdü.';

  @override
  String get engineThisSetGotTooBig => 'Bu küme çok büyüdü.';

  @override
  String get engineThisStackGotTooBig => 'Bu yığın çok büyüdü.';

  @override
  String get engineThisStackIsEmpty => 'Bu yığın boş.';

  @override
  String get engineThisHeapGotTooBig => 'Bu öncelik kuyruğu çok büyüdü.';

  @override
  String get engineThisHeapIsEmpty => 'Bu öncelik kuyruğu boş.';

  @override
  String get engineThisQueueGotTooBig => 'Bu kuyruk çok büyüdü.';

  @override
  String get engineThisQueueIsEmpty => 'Bu kuyruk boş.';

  @override
  String get engineThisBlockCannotRunYet => 'Bu blok henüz çalışamaz.';

  @override
  String get engineThisBlockIsMissingAName => 'Bu blokta bir ad eksik.';

  @override
  String get engineThisBlockCanOnlySwapTwoNames =>
      'Bu blok yalnızca iki adı yer değiştirebilir.';

  @override
  String get engineThereIsNothingHere => 'Burada bir şey yok (NOTHING).';

  @override
  String get engineThisBlockNeedsAYesOrNo =>
      'Bu blok bir evet / hayır (TRUE / FALSE) değeri bekliyor.';

  @override
  String get engineThisBlockNeedsANumberSomeText =>
      'Bu blok anahtar olarak bir sayı, metin ya da evet / hayır değeri bekliyor.';

  @override
  String get engineAPositionHasToBeAWhole => 'Bir konum tam sayı olmalı.';

  @override
  String get engineThatPositionIsOutsideTheList => 'Bu konum listenin dışında.';

  @override
  String get engineThisProgramIsNestedTooDeeply =>
      'Bu program çok derin iç içe.';

  @override
  String get engineThisProgramTookTooManySteps =>
      'Bu program çok fazla adım attı.';

  @override
  String get engineThisProgramUsedTooMuchMemory =>
      'Bu program çok fazla bellek kullandı.';

  @override
  String get engineThisPuzzleHasNoTestCases => 'Bu bulmacanın test vakası yok.';

  @override
  String get engineEveryCasePassed => 'Tüm vakalar geçti.';

  @override
  String get engineThisCaseDidNotComeOutThe =>
      'Bu vaka bulmacanın beklediği gibi sonuçlanmadı.';

  @override
  String get engineAHiddenCaseDidNotComeOut =>
      'Gizli bir vaka bulmacanın beklediği gibi sonuçlanmadı.';

  @override
  String engineMaxBlocks(String max) {
    return 'Bu bulmaca en fazla $max bloğa izin veriyor.';
  }

  @override
  String get engineChooseAFunction => 'Bir fonksiyon seç.';

  @override
  String get engineFunctionAtTop =>
      'Bir FUNCTION, programın en üstünde ve diğer blokların dışında kalmalı.';

  @override
  String get engineFunctionMalformed => 'Bu FUNCTION doğru kurulmamış.';

  @override
  String engineTwoFunctions(String name) {
    return '$name adında iki FUNCTION bloğu var.';
  }

  @override
  String engineNoFunction(String name) {
    return '$name adında bir FUNCTION yok.';
  }

  @override
  String engineWrongArity(String name) {
    return 'Bu CALL, $name için yanlış sayıda değer veriyor.';
  }

  @override
  String engineNotInFunction(String name) {
    return '$name bir FUNCTION içinde bilinmez: onu bir değer olarak geçir.';
  }

  @override
  String engineNoReturn(String name) {
    return 'FUNCTION $name, RETURN olmadan bitti.';
  }

  @override
  String engineNoValueFor(String name) {
    return 'Bu program $name için bir değer almadı.';
  }

  @override
  String engineCaseFailed(String id) {
    return '$id vakası bulmacanın beklediği gibi sonuçlanmadı.';
  }
}

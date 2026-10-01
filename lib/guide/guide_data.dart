import 'package:algorun_engine/algorun_engine.dart';

/// The block reference's content: every block a puzzle can offer, and the
/// basic ideas behind them. Block names stay English in every language (they
/// are the language of the game); each entry gives the Turkish name, what it
/// does in both languages, and a small example written the way the editor
/// lays the blocks out.
final class GuideEntry {
  const GuideEntry({
    required this.term,
    required this.tr,
    required this.en,
    required this.trText,
    this.example,
    this.trExample,
  });

  /// The English name as the editor shows it: `IF`, `GET ELEMENT`.
  final String term;

  /// The Turkish name: `EĞER / KOŞUL`, `Konum`.
  final String tr;

  /// What it means, in English.
  final String en;

  /// What it means, in Turkish.
  final String trText;

  /// A small example in block words, in the editor's order. Parentheses
  /// show a block sitting in a slot of another block.
  final String? example;

  /// The example with Turkish notes, when the example has words that are not
  /// block names.
  final String? trExample;

  String text(String language) => language == 'tr' ? trText : en;

  String? exampleFor(String language) => language == 'tr' ? (trExample ?? example) : example;
}

/// One entry per block a puzzle can offer (a test checks that every block
/// the campaign allows has one). SWAP, COPY and TEXT are left out: no puzzle
/// offers them and they have nothing to plug in yet.
/// CALL, whatever the number of values it passes (one entry in the guide).
const _call = GuideEntry(
  term: 'CALL',
  tr: 'ÇAĞIR',
  en: 'Runs a FUNCTION with the values in its slots and stands for the value it RETURNs. Every call has its own variables; a list passed in is the same list, not a copy.',
  trText: 'Bir FUNCTION\'ı yuvalarındaki değerlerle çalıştırır ve onun RETURN ettiği değerin yerine geçer. Her çağrının kendi değişkenleri vardır; içeri verilen bir liste kopya değil, aynı listedir.',
  example: 'RETURN CALL fact (n)',
);

const Map<String, GuideEntry> blockGuide = {
  // ---- control ----
  BlockIds.ctrlIf: GuideEntry(
    term: 'IF',
    tr: 'EĞER / KOŞUL',
    en: 'Checks a condition. The blocks inside THEN run only when the condition is true. ADD ELSE gives a second list that runs when it is false.',
    trText: 'Bir koşulu kontrol eder. Koşul doğruysa THEN içindeki bloklar çalıştırılır. ADD ELSE, koşul yanlışsa çalışan ikinci bir liste ekler.',
    example: 'IF x GREATER THAN 3\n  THEN  SET found TO TRUE\n  ELSE  SET found TO FALSE',
  ),
  BlockIds.ctrlElse: GuideEntry(
    term: 'ELSE',
    tr: 'DEĞİLSE',
    en: 'The second branch of an IF: its blocks run when the condition is false.',
    trText: 'IF bloğunun ikinci dalı: koşul yanlışsa buradaki bloklar çalışır.',
    example: 'IF c IS NOTHING\n  THEN  SET total TO 1\n  ELSE  SET total TO c PLUS 1',
  ),
  BlockIds.ctrlWhile: GuideEntry(
    term: 'WHILE',
    tr: 'İKEN / DÖNGÜ',
    en: 'Repeats the blocks inside DO for as long as the condition stays true. Something inside must change, or the loop never ends.',
    trText: 'Koşul doğru kaldığı sürece DO içindeki blokları tekrar eder. İçeride bir şey değişmeli, yoksa döngü hiç bitmez.',
    example: 'SET i TO 0\nWHILE i LESS THAN (nums LENGTH)\n  DO  INCREMENT i',
  ),
  BlockIds.ctrlForRange: GuideEntry(
    term: 'FOR',
    tr: 'SAYARAK DÖNGÜ',
    en: 'Counts a variable FROM a start number TO an end number (the end is not included), BY a step, and runs DO once for each value.',
    trText: 'Bir değişkeni başlangıç sayısından (FROM) bitiş sayısına (TO, bitiş dahil değil) adım (BY) kadar sayar ve her değer için DO kısmını bir kez çalıştırır.',
    example: 'FOR i FROM 0 TO (nums LENGTH) BY 1\n  DO  SET total TO total PLUS (nums GET ELEMENT i)',
  ),
  BlockIds.ctrlForEach: GuideEntry(
    term: 'FOR EACH',
    tr: 'HER BİRİ İÇİN',
    en: 'Takes the items of a list one by one, in order, puts each into a variable, and runs DO for it. The variable holds the item\'s value, not its position.',
    trText: 'Bir listenin öğelerini sırayla tek tek alır, her birini bir değişkene koyar ve DO kısmını onun için çalıştırır. Değişken öğenin konumunu değil, değerini tutar.',
    example: 'FOR EACH r IN readings\n  DO  IF r GREATER THAN limit\n        THEN  INCREMENT count',
  ),
  BlockIds.ctrlBreak: GuideEntry(
    term: 'BREAK',
    tr: 'DÖNGÜDEN ÇIK',
    en: 'Leaves the innermost loop at once; the program continues after that loop.',
    trText: 'İçinde bulunduğu en yakın döngüden hemen çıkar; program o döngünün arkasından devam eder.',
    example: 'FOR EACH x IN nums\n  DO  IF x EQUAL 0\n        THEN  BREAK',
  ),
  BlockIds.ctrlContinue: GuideEntry(
    term: 'CONTINUE',
    tr: 'SONRAKİ TURA GEÇ',
    en: 'Skips the rest of this round of the loop and goes on with the next round.',
    trText: 'Döngünün bu turunun geri kalanını atlar ve bir sonraki tura geçer.',
    example: 'FOR EACH x IN nums\n  DO  IF x LESS THAN 0\n        THEN  CONTINUE',
  ),
  BlockIds.ctrlReturn: GuideEntry(
    term: 'RETURN',
    tr: 'DÖNDÜR',
    en: 'Ends the program and gives back its answer. The answer must be what the puzzle asks for (RETURNS in the brief). Inside a FUNCTION it ends only that function and gives its value back to the CALL.',
    trText: 'Programı bitirir ve cevabını geri verir. Cevap bulmacanın istediği şey olmalı (görevdeki DÖNDÜRÜR). Bir FUNCTION içinde yalnızca o fonksiyonu bitirir ve değerini CALL\'a geri verir.',
    example: 'RETURN count',
  ),
  // ---- functions (L2) ----
  BlockIds.fnDef: GuideEntry(
    term: 'FUNCTION',
    tr: 'FONKSİYON',
    en: 'A function the puzzle asks you to write: its name and the values it takes are given. Build its steps inside it; RETURN gives its answer back to whoever CALLed it. A function may CALL itself: give it a case that RETURNs without calling again, or it never ends.',
    trText: 'Bulmacanın senden yazmanı istediği bir fonksiyon: adı ve aldığı değerler verilmiştir. Adımlarını içine kur; RETURN cevabını onu CALL ile çağırana geri verir. Bir fonksiyon kendini de CALL ile çağırabilir: ona yeniden çağırmadan RETURN eden bir durum ver, yoksa hiç bitmez.',
    example: 'FUNCTION fact (k)\n  IF k LESS OR EQUAL 1\n    THEN  RETURN 1\n  RETURN k TIMES CALL fact (k MINUS 1)',
  ),
  BlockIds.fnCall: _call,
  BlockIds.fnCall1: _call,
  BlockIds.fnCall2: _call,
  BlockIds.fnCall3: _call,
  // ---- values and variables ----
  BlockIds.varSet: GuideEntry(
    term: 'SET',
    tr: 'ATA',
    en: 'Puts a value into a variable, replacing what it held. Tap the name to choose the variable.',
    trText: 'Bir değişkene bir değer koyar; eski değerin yerine geçer. Değişkeni seçmek için ada dokun.',
    example: 'SET best TO 0\nSET best TO best MAX x',
  ),
  BlockIds.varGet: GuideEntry(
    term: 'a name',
    tr: 'DEĞİŞKENİ OKU',
    en: 'A name in a slot, like readings or count, reads what that variable holds right now. Tap a name under GIVENS or VARIABLES to put it in the selected slot.',
    trText: 'Bir yuvadaki ad (ör. readings ya da count), o değişkenin şu anki değerini okur. Seçili yuvaya koymak için VERİLENLER ya da DEĞİŞKENLER altındaki bir ada dokun.',
    example: 'RETURN count',
  ),
  BlockIds.varInc: GuideEntry(
    term: 'INCREMENT',
    tr: 'BİR ARTIR',
    en: 'Adds 1 to a number variable. Same as SET x TO x PLUS 1.',
    trText: 'Sayı tutan bir değişkene 1 ekler. SET x TO x PLUS 1 ile aynıdır.',
    example: 'INCREMENT count',
  ),
  BlockIds.varDec: GuideEntry(
    term: 'DECREMENT',
    tr: 'BİR AZALT',
    en: 'Takes 1 away from a number variable. Same as SET x TO x MINUS 1.',
    trText: 'Sayı tutan bir değişkenden 1 çıkarır. SET x TO x MINUS 1 ile aynıdır.',
    example: 'DECREMENT hi',
  ),
  BlockIds.litNum: GuideEntry(
    term: 'NUMBER',
    tr: 'SAYI',
    en: 'A fixed whole number. Tap it to type another one on the number pad; +/− makes it negative.',
    trText: 'Sabit bir tam sayı. Başka bir sayı yazmak için dokun; +/− onu negatif yapar.',
    example: 'SET count TO 0',
  ),
  BlockIds.litBool: GuideEntry(
    term: 'TRUE / FALSE',
    tr: 'DOĞRU / YANLIŞ',
    en: 'A yes / no value: TRUE or FALSE. Tap it to choose the other one.',
    trText: 'Evet / hayır değeri: TRUE (doğru) ya da FALSE (yanlış). Diğerini seçmek için dokun.',
    example: 'RETURN FALSE',
  ),
  BlockIds.litNull: GuideEntry(
    term: 'NOTHING',
    tr: 'HİÇBİR ŞEY / BOŞ',
    en: 'The empty value: no node, no answer found. Used for "no next car" or "nothing here yet".',
    trText: 'Boş değer: düğüm yok, cevap bulunamadı. "Sonraki vagon yok" ya da "burada henüz bir şey yok" için kullanılır.',
    example: 'SET prev TO NOTHING',
  ),
  // ---- logic ----
  BlockIds.cmpEq: GuideEntry(
    term: 'EQUAL',
    tr: 'EŞİT',
    en: 'TRUE when both sides are the same value.',
    trText: 'İki taraf aynı değerse TRUE olur.',
    example: 'IF (x REMAINDER 2) EQUAL 0',
  ),
  BlockIds.cmpNe: GuideEntry(
    term: 'NOT EQUAL',
    tr: 'EŞİT DEĞİL',
    en: 'TRUE when the two sides are different.',
    trText: 'İki taraf farklıysa TRUE olur.',
    example: 'IF here NOT EQUAL goal',
  ),
  BlockIds.cmpLt: GuideEntry(
    term: 'LESS THAN',
    tr: 'KÜÇÜKTÜR',
    en: 'TRUE when the left number is smaller than the right one.',
    trText: 'Soldaki sayı sağdakinden küçükse TRUE olur.',
    example: 'WHILE i LESS THAN (nums LENGTH)',
  ),
  BlockIds.cmpLe: GuideEntry(
    term: 'LESS OR EQUAL',
    tr: 'KÜÇÜK YA DA EŞİT',
    en: 'TRUE when the left number is smaller than or equal to the right one.',
    trText: 'Soldaki sayı sağdakinden küçük ya da ona eşitse TRUE olur.',
    example: 'WHILE lo LESS OR EQUAL hi',
  ),
  BlockIds.cmpGt: GuideEntry(
    term: 'GREATER THAN',
    tr: 'BÜYÜKTÜR',
    en: 'TRUE when the left number is larger than the right one. Equal is not greater.',
    trText: 'Soldaki sayı sağdakinden büyükse TRUE olur. Eşit olmak büyük olmak değildir.',
    example: 'IF r GREATER THAN limit',
  ),
  BlockIds.cmpGe: GuideEntry(
    term: 'GREATER OR EQUAL',
    tr: 'BÜYÜK YA DA EŞİT',
    en: 'TRUE when the left number is larger than or equal to the right one.',
    trText: 'Soldaki sayı sağdakinden büyük ya da ona eşitse TRUE olur.',
    example: 'IF total GREATER OR EQUAL quota',
  ),
  BlockIds.logicAnd: GuideEntry(
    term: 'AND',
    tr: 'VE',
    en: 'TRUE only when both conditions are true. If the left one is false, the right one is not even checked.',
    trText: 'Yalnızca iki koşul da doğruysa TRUE olur. Sol taraf yanlışsa sağ taraf hiç kontrol edilmez.',
    example: 'IF (node IS NOT NOTHING) AND ((node NODE VALUE) EQUAL bad)',
  ),
  BlockIds.logicOr: GuideEntry(
    term: 'OR',
    tr: 'VEYA',
    en: 'TRUE when at least one of the two conditions is true. If the left one is true, the right one is not checked.',
    trText: 'İki koşuldan en az biri doğruysa TRUE olur. Sol taraf doğruysa sağ taraf kontrol edilmez.',
    example: 'IF (x LESS THAN 0) OR (x GREATER THAN 9)',
  ),
  BlockIds.logicNot: GuideEntry(
    term: 'NOT',
    tr: 'DEĞİL',
    en: 'Turns TRUE into FALSE and FALSE into TRUE.',
    trText: 'TRUE\'yu FALSE\'a, FALSE\'u TRUE\'ya çevirir.',
    example: 'WHILE NOT (line IS EMPTY)',
  ),
  BlockIds.logicIsNothing: GuideEntry(
    term: 'IS NOTHING',
    tr: 'BOŞ MU',
    en: 'TRUE when a value that may be empty is empty (NOTHING). In the ELSE of such an IF, the value is known to be there.',
    trText: 'Boş olabilecek bir değer boşsa (NOTHING) TRUE olur. Böyle bir IF\'in ELSE kısmında değerin var olduğu bilinir.',
    example: 'SET c TO (counts GET x)\nIF c IS NOTHING\n  THEN  PUT counts x 1',
  ),
  BlockIds.logicIsNotNothing: GuideEntry(
    term: 'IS NOT NOTHING',
    tr: 'BOŞ DEĞİL Mİ',
    en: 'TRUE when a value that may be empty holds something. Inside the THEN (or the WHILE), the value can be used safely.',
    trText: 'Boş olabilecek bir değer bir şey tutuyorsa TRUE olur. THEN (ya da WHILE) içinde değer güvenle kullanılabilir.',
    example: 'WHILE node IS NOT NOTHING\n  DO  SET node TO (node NEXT NODE)',
  ),
  // ---- math ----
  BlockIds.arithAdd: GuideEntry(
    term: 'PLUS',
    tr: 'ARTI',
    en: 'Adds two numbers.',
    trText: 'İki sayıyı toplar.',
    example: 'SET total TO total PLUS x',
  ),
  BlockIds.arithSub: GuideEntry(
    term: 'MINUS',
    tr: 'EKSİ',
    en: 'Takes the right number away from the left one.',
    trText: 'Sağdaki sayıyı soldakinden çıkarır.',
    example: 'SET need TO tuning MINUS x',
  ),
  BlockIds.arithMul: GuideEntry(
    term: 'TIMES',
    tr: 'ÇARPI',
    en: 'Multiplies two numbers.',
    trText: 'İki sayıyı çarpar.',
    example: 'SET area TO width TIMES h',
  ),
  BlockIds.arithDiv: GuideEntry(
    term: 'DIVIDE',
    tr: 'BÖLÜ',
    en: 'Divides the left number by the right one; 7 DIVIDE 2 is 3.5. Dividing by zero is an error.',
    trText: 'Soldaki sayıyı sağdakine böler; 7 DIVIDE 2 sonucu 3.5\'tir. Sıfıra bölmek hatadır.',
    example: 'SET half TO total DIVIDE 2',
  ),
  BlockIds.arithFloorDiv: GuideEntry(
    term: 'FLOOR DIVIDE',
    tr: 'TAM BÖLME',
    en: 'Divides and rounds down to a whole number; 7 FLOOR DIVIDE 2 is 3. Good for a middle position.',
    trText: 'Böler ve sonucu aşağı yuvarlayarak tam sayı yapar; 7 FLOOR DIVIDE 2 sonucu 3\'tür. Orta konumu bulmak için uygundur.',
    example: 'SET mid TO (lo PLUS hi) FLOOR DIVIDE 2',
  ),
  BlockIds.arithMod: GuideEntry(
    term: 'REMAINDER',
    tr: 'KALAN (MOD)',
    en: 'What is left after dividing; 7 REMAINDER 2 is 1. (x REMAINDER 2) EQUAL 0 means x is even.',
    trText: 'Bölmeden sonra kalan; 7 REMAINDER 2 sonucu 1\'dir. (x REMAINDER 2) EQUAL 0, x çift demektir.',
    example: 'IF (x REMAINDER 2) EQUAL 0',
  ),
  BlockIds.arithMin: GuideEntry(
    term: 'MIN',
    tr: 'EN KÜÇÜK',
    en: 'The smaller of two numbers.',
    trText: 'İki sayıdan küçük olanı.',
    example: 'SET low TO low MIN balance',
  ),
  BlockIds.arithMax: GuideEntry(
    term: 'MAX',
    tr: 'EN BÜYÜK',
    en: 'The larger of two numbers.',
    trText: 'İki sayıdan büyük olanı.',
    example: 'SET best TO best MAX total',
  ),
  BlockIds.arithAbs: GuideEntry(
    term: 'ABSOLUTE',
    tr: 'MUTLAK DEĞER',
    en: 'The number without its minus sign; ABSOLUTE −4 is 4.',
    trText: 'Sayının eksi işareti olmadan hâli; ABSOLUTE −4 sonucu 4\'tür.',
    example: 'SET gap TO ABSOLUTE (a MINUS b)',
  ),
  // ---- lists ----
  BlockIds.arrGet: GuideEntry(
    term: 'GET ELEMENT',
    tr: 'ÖĞEYİ AL',
    en: 'The value at a position (index) in a list. Positions start at 0: nums GET ELEMENT 0 is the first item. The position is not the value.',
    trText: 'Bir listede belirli bir konumdaki (index) değer. Konumlar 0\'dan başlar: nums GET ELEMENT 0 ilk öğedir. Konum, değerin kendisi değildir.',
    example: 'SET x TO (readings GET ELEMENT i)',
  ),
  BlockIds.arrSet: GuideEntry(
    term: 'SET ELEMENT',
    tr: 'ÖĞEYİ DEĞİŞTİR',
    en: 'Replaces the value at a position in a list. Slots: the list, the position, the new value.',
    trText: 'Listede bir konumdaki değeri değiştirir. Yuvalar: liste, konum, yeni değer.',
    example: 'SET ELEMENT dist next (d PLUS 1)',
  ),
  BlockIds.arrLen: GuideEntry(
    term: 'LENGTH',
    tr: 'UZUNLUK',
    en: 'How many items a list holds. The last position is one less: (nums LENGTH) MINUS 1.',
    trText: 'Listenin kaç öğe tuttuğu. Son konum bir eksiğidir: (nums LENGTH) MINUS 1.',
    example: 'WHILE i LESS THAN (nums LENGTH)',
  ),
  BlockIds.arrAppend: GuideEntry(
    term: 'APPEND',
    tr: 'SONA EKLE',
    en: 'Adds a value at the end of a list. Slots: the list, the value.',
    trText: 'Listenin sonuna bir değer ekler. Yuvalar: liste, değer.',
    example: 'APPEND result x',
  ),
  BlockIds.arrRemove: GuideEntry(
    term: 'REMOVE AT',
    tr: 'KONUMDAN SİL',
    en: 'Removes the item at a position; the items after it move one place forward.',
    trText: 'Bir konumdaki öğeyi siler; ondan sonraki öğeler bir yer öne kayar.',
    example: 'REMOVE AT line 0',
  ),
  BlockIds.arrSwap: GuideEntry(
    term: 'SWAP ELEMENTS',
    tr: 'ÖĞELERİN YERİNİ DEĞİŞTİR',
    en: 'Exchanges the items at two positions of a list.',
    trText: 'Listede iki konumdaki öğelerin yerini değiştirir.',
    example: 'SWAP ELEMENTS nums i j',
  ),
  BlockIds.newArray: GuideEntry(
    term: 'NEW LIST',
    tr: 'YENİ LİSTE',
    en: 'A new, empty list to fill with APPEND.',
    trText: 'APPEND ile doldurulacak yeni ve boş bir liste.',
    example: 'SET result TO NEW LIST',
  ),
  // ---- maps ----
  BlockIds.mapGet: GuideEntry(
    term: 'GET (map)',
    tr: 'EŞLEMEDEN AL',
    en: 'The value stored for a key in a map, or NOTHING if the key is not there yet. Check it with IS NOTHING.',
    trText: 'Bir eşlemede bir anahtar için saklanan değer; anahtar henüz yoksa NOTHING. IS NOTHING ile kontrol et.',
    example: 'SET c TO (counts GET x)',
  ),
  BlockIds.mapSet: GuideEntry(
    term: 'PUT',
    tr: 'EŞLEMEYE KOY',
    en: 'Stores a value for a key in a map, replacing the old one. Slots: the map, the key, the value.',
    trText: 'Bir eşlemede bir anahtar için değer saklar; eskisinin yerine geçer. Yuvalar: eşleme, anahtar, değer.',
    example: 'PUT counts x (c PLUS 1)',
  ),
  BlockIds.mapHas: GuideEntry(
    term: 'HAS KEY',
    tr: 'ANAHTAR VAR MI',
    en: 'TRUE when the map holds a value for the key.',
    trText: 'Eşleme o anahtar için bir değer tutuyorsa TRUE olur.',
    example: 'IF counts HAS KEY x',
  ),
  BlockIds.mapRemove: GuideEntry(
    term: 'REMOVE KEY',
    tr: 'ANAHTARI SİL',
    en: 'Removes a key (and its value) from a map.',
    trText: 'Bir anahtarı (ve değerini) eşlemeden siler.',
    example: 'REMOVE KEY counts kind',
  ),
  BlockIds.mapSize: GuideEntry(
    term: 'SIZE (map)',
    tr: 'EŞLEME BOYUTU',
    en: 'How many keys a map holds.',
    trText: 'Eşlemenin kaç anahtar tuttuğu.',
    example: 'WHILE (counts SIZE) GREATER THAN k',
  ),
  BlockIds.newMap: GuideEntry(
    term: 'NEW MAP',
    tr: 'YENİ EŞLEME',
    en: 'A new, empty map (key → value).',
    trText: 'Yeni ve boş bir eşleme (anahtar → değer).',
    example: 'SET counts TO NEW MAP',
  ),
  // ---- sets ----
  BlockIds.setAdd: GuideEntry(
    term: 'ADD',
    tr: 'KÜMEYE EKLE',
    en: 'Adds a value to a set. A set holds each value at most once.',
    trText: 'Bir kümeye değer ekler. Küme her değeri en fazla bir kez tutar.',
    example: 'ADD seen x',
  ),
  BlockIds.setHas: GuideEntry(
    term: 'HAS',
    tr: 'KÜMEDE VAR MI',
    en: 'TRUE when the value is in the set. Asking costs one step, however big the set is.',
    trText: 'Değer kümedeyse TRUE olur. Sormak, küme ne kadar büyük olursa olsun tek adım tutar.',
    example: 'IF seen HAS need',
  ),
  BlockIds.setRemove: GuideEntry(
    term: 'REMOVE',
    tr: 'KÜMEDEN SİL',
    en: 'Removes a value from a set.',
    trText: 'Kümeden bir değeri siler.',
    example: 'REMOVE seen x',
  ),
  BlockIds.setSize: GuideEntry(
    term: 'SIZE (set)',
    tr: 'KÜME BOYUTU',
    en: 'How many values a set holds.',
    trText: 'Kümenin kaç değer tuttuğu.',
    example: 'RETURN (seen SIZE)',
  ),
  BlockIds.newSet: GuideEntry(
    term: 'NEW SET',
    tr: 'YENİ KÜME',
    en: 'A new, empty set.',
    trText: 'Yeni ve boş bir küme.',
    example: 'SET seen TO NEW SET',
  ),
  // ---- stacks and queues ----
  BlockIds.stackPush: GuideEntry(
    term: 'PUSH',
    tr: 'YIĞINA KOY',
    en: 'Puts a value on top of a stack. The last one in is the first one out.',
    trText: 'Bir yığının üstüne değer koyar. Son giren ilk çıkar.',
    example: 'PUSH open c',
  ),
  BlockIds.stackPop: GuideEntry(
    term: 'POP',
    tr: 'YIĞINDAN AL',
    en: 'Takes the top value off a stack and gives it. An empty stack is an error: check IS EMPTY first.',
    trText: 'Yığının üstündeki değeri çıkarır ve verir. Boş yığın hatadır: önce IS EMPTY ile kontrol et.',
    example: 'SET top TO (waiting POP)',
  ),
  BlockIds.stackPeek: GuideEntry(
    term: 'PEEK',
    tr: 'ÜSTE BAK',
    en: 'The top value of a stack, without taking it off.',
    trText: 'Yığının üstündeki değer; çıkarmadan bakar.',
    example: 'IF (st PEEK) GREATER THAN h',
  ),
  BlockIds.stackEmpty: GuideEntry(
    term: 'IS EMPTY (stack)',
    tr: 'YIĞIN BOŞ MU',
    en: 'TRUE when the stack holds nothing.',
    trText: 'Yığın hiçbir şey tutmuyorsa TRUE olur.',
    example: 'IF open IS EMPTY\n  THEN  RETURN FALSE',
  ),
  BlockIds.newStack: GuideEntry(
    term: 'NEW STACK',
    tr: 'YENİ YIĞIN',
    en: 'A new, empty stack.',
    trText: 'Yeni ve boş bir yığın.',
    example: 'SET open TO NEW STACK',
  ),
  BlockIds.queueEnq: GuideEntry(
    term: 'ENQUEUE',
    tr: 'KUYRUĞA EKLE',
    en: 'Adds a value at the back of a queue. The first one in is the first one out.',
    trText: 'Kuyruğun arkasına değer ekler. İlk giren ilk çıkar.',
    example: 'ENQUEUE line start',
  ),
  BlockIds.queueDeq: GuideEntry(
    term: 'DEQUEUE',
    tr: 'KUYRUKTAN AL',
    en: 'Takes the front value out of a queue and gives it. Check IS EMPTY first.',
    trText: 'Kuyruğun önündeki değeri çıkarır ve verir. Önce IS EMPTY ile kontrol et.',
    example: 'SET here TO (line DEQUEUE)',
  ),
  BlockIds.queueFront: GuideEntry(
    term: 'FRONT',
    tr: 'ÖNE BAK',
    en: 'The front value of a queue, without taking it out.',
    trText: 'Kuyruğun önündeki değer; çıkarmadan bakar.',
    example: 'IF (line FRONT) EQUAL goal',
  ),
  BlockIds.queueEmpty: GuideEntry(
    term: 'IS EMPTY (queue)',
    tr: 'KUYRUK BOŞ MU',
    en: 'TRUE when the queue holds nothing.',
    trText: 'Kuyruk hiçbir şey tutmuyorsa TRUE olur.',
    example: 'WHILE NOT (line IS EMPTY)',
  ),
  BlockIds.newQueue: GuideEntry(
    term: 'NEW QUEUE',
    tr: 'YENİ KUYRUK',
    en: 'A new, empty queue.',
    trText: 'Yeni ve boş bir kuyruk.',
    example: 'SET line TO NEW QUEUE',
  ),
  // ---- structures ----
  BlockIds.llValue: GuideEntry(
    term: 'NODE VALUE (chain)',
    tr: 'HALKA DEĞERİ',
    en: 'The number written on a link of a chain (linked list).',
    trText: 'Bir zincirin (bağlı liste) halkasının üzerindeki sayı.',
    example: 'SET total TO total PLUS (node NODE VALUE)',
  ),
  BlockIds.llNext: GuideEntry(
    term: 'NEXT NODE',
    tr: 'SONRAKİ HALKA',
    en: 'The link after this one, or NOTHING at the end of the chain.',
    trText: 'Bu halkadan sonraki halka; zincirin sonunda NOTHING.',
    example: 'SET node TO (node NEXT NODE)',
  ),
  BlockIds.llSetNext: GuideEntry(
    term: 'SET NEXT',
    tr: 'SONRAKİNİ BAĞLA',
    en: 'Makes a link point to another link (or NOTHING): the chain is recoupled, nothing is copied. Slots: the link, the link it should point to.',
    trText: 'Bir halkayı başka bir halkayı (ya da NOTHING) gösterecek şekilde bağlar: zincir yeniden bağlanır, hiçbir şey kopyalanmaz. Yuvalar: halka, göstereceği halka.',
    example: 'SET NEXT node prev',
  ),
  BlockIds.treeValue: GuideEntry(
    term: 'NODE VALUE (tree)',
    tr: 'DÜĞÜM DEĞERİ',
    en: 'The number written on a node of a tree.',
    trText: 'Bir ağacın düğümünün üzerindeki sayı.',
    example: 'IF (node NODE VALUE) GREATER THAN prev',
  ),
  BlockIds.treeLeft: GuideEntry(
    term: 'LEFT',
    tr: 'SOL ÇOCUK',
    en: 'The left child of a tree node, or NOTHING if it has none.',
    trText: 'Bir ağaç düğümünün sol çocuğu; yoksa NOTHING.',
    example: 'SET child TO (node LEFT)',
  ),
  BlockIds.treeRight: GuideEntry(
    term: 'RIGHT',
    tr: 'SAĞ ÇOCUK',
    en: 'The right child of a tree node, or NOTHING if it has none.',
    trText: 'Bir ağaç düğümünün sağ çocuğu; yoksa NOTHING.',
    example: 'SET child TO (node RIGHT)',
  ),
  BlockIds.graphNeighbors: GuideEntry(
    term: 'NEIGHBORS',
    tr: 'KOMŞULAR',
    en: 'The list of nodes you can go to from a node of a graph, in one step.',
    trText: 'Bir çizgede bir düğümden tek adımda gidilebilen düğümlerin listesi.',
    example: 'FOR EACH next IN (metro NEIGHBORS here)',
  ),
  BlockIds.graphMark: GuideEntry(
    term: 'MARK',
    tr: 'İŞARETLE',
    en: 'Marks a node of a graph as visited, so a search does not come back to it.',
    trText: 'Bir çizge düğümünü ziyaret edilmiş olarak işaretler; böylece arama ona geri dönmez.',
    example: 'MARK islands s',
  ),
  BlockIds.graphVisited: GuideEntry(
    term: 'VISITED',
    tr: 'ZİYARET EDİLDİ Mİ',
    en: 'TRUE when a node of the graph has been marked.',
    trText: 'Çizgenin bir düğümü işaretlenmişse TRUE olur.',
    example: 'IF NOT (islands VISITED next)',
  ),
  BlockIds.graphNodeCount: GuideEntry(
    term: 'NODE COUNT',
    tr: 'DÜĞÜM SAYISI',
    en: 'How many nodes a graph has; they are numbered 0 to (NODE COUNT) MINUS 1.',
    trText: 'Çizgenin kaç düğümü olduğu; düğümler 0\'dan (NODE COUNT) MINUS 1\'e kadar numaralıdır.',
    example: 'FOR s FROM 0 TO (islands NODE COUNT) BY 1',
  ),
};

/// The ideas the blocks are built on.
const List<GuideEntry> conceptGuide = [
  GuideEntry(
    term: 'Variable',
    tr: 'Değişken',
    en: 'A named box that holds one value, like count or best. SET puts a value in; using the name reads it. The puzzle gives the names: GIVENS are its inputs, VARIABLES are yours to use.',
    trText: 'Tek bir değer tutan adlandırılmış bir kutu, örneğin count ya da best. SET içine değer koyar; adı kullanmak değeri okur. Adları bulmaca verir: VERİLENLER onun girdileri, DEĞİŞKENLER senin kullanımın içindir.',
    example: 'SET count TO 0\nINCREMENT count',
  ),
  GuideEntry(
    term: 'Value',
    tr: 'Değer',
    en: 'Something a program works with: a number, TRUE / FALSE, a list, a map, a node, or NOTHING.',
    trText: 'Programın üzerinde çalıştığı şey: bir sayı, TRUE / FALSE, bir liste, bir eşleme, bir düğüm ya da NOTHING.',
  ),
  GuideEntry(
    term: 'Index / Position',
    tr: 'Konum (index)',
    en: 'Where an item sits in a list, counting from 0. A variable can hold a position (i) instead of a value: readings GET ELEMENT i is the value at that position. A puzzle that asks for the position wants i, not the value.',
    trText: 'Bir öğenin listede nerede durduğu; 0\'dan sayılır. Bir değişken değer yerine bir konum (i) tutabilir: readings GET ELEMENT i o konumdaki değerdir. Konumu soran bir bulmaca değeri değil, i\'yi ister.',
    example: 'readings = [7, 9, 4]\nposition 0 → 7\nposition 1 → 9\nposition 2 → 4\n\nSET best TO 1\n  best is a position\n(readings GET ELEMENT best) → 9\n  the value there',
    trExample: 'readings = [7, 9, 4]\nkonum 0 → 7\nkonum 1 → 9\nkonum 2 → 4\n\nSET best TO 1\n  best bir konumdur\n(readings GET ELEMENT best) → 9\n  oradaki değer',
  ),
  GuideEntry(
    term: 'List',
    tr: 'Liste (dizi)',
    en: 'Values in order. LENGTH says how many; GET ELEMENT reads one position; APPEND adds at the end.',
    trText: 'Sıralı değerler. LENGTH kaç tane olduğunu söyler; GET ELEMENT bir konumu okur; APPEND sona ekler.',
    example: 'SET result TO NEW LIST\nAPPEND result 5',
  ),
  GuideEntry(
    term: 'Condition',
    tr: 'Koşul',
    en: 'A question whose answer is TRUE or FALSE, like x GREATER THAN 3. IF and WHILE are driven by conditions.',
    trText: 'Cevabı TRUE ya da FALSE olan bir soru, örneğin x GREATER THAN 3. IF ve WHILE koşullarla çalışır.',
    example: 'IF x GREATER THAN 3',
  ),
  GuideEntry(
    term: 'Loop',
    tr: 'Döngü',
    en: 'Blocks that run again and again: WHILE (as long as a condition holds), FOR (counting), FOR EACH (over a list).',
    trText: 'Tekrar tekrar çalışan bloklar: WHILE (bir koşul sürdükçe), FOR (sayarak), FOR EACH (bir listenin üzerinden).',
    example: 'FOR EACH r IN readings\n  DO  INCREMENT count',
  ),
  GuideEntry(
    term: 'Map',
    tr: 'Eşleme (map)',
    en: 'Pairs each key with a value, like a word with its count. GET finds the value for a key, or NOTHING.',
    trText: 'Her anahtarı bir değerle eşler, örneğin bir kelimeyi sayısıyla. GET bir anahtarın değerini ya da NOTHING bulur.',
    example: 'PUT counts 7 1\n(counts GET 7) → 1\n(counts GET 5) → NOTHING',
  ),
  GuideEntry(
    term: 'Set',
    tr: 'Küme',
    en: 'A collection where each value appears at most once. HAS answers "is it there?" in one step.',
    trText: 'Her değerin en fazla bir kez bulunduğu bir koleksiyon. HAS "orada mı?" sorusunu tek adımda cevaplar.',
    example: 'ADD seen 4\n(seen HAS 4) → TRUE',
  ),
  GuideEntry(
    term: 'Stack / Queue',
    tr: 'Yığın / Kuyruk',
    en: 'A stack gives back the last value put in (PUSH / POP); a queue gives back the first (ENQUEUE / DEQUEUE).',
    trText: 'Yığın en son konan değeri geri verir (PUSH / POP); kuyruk ise ilk konanı (ENQUEUE / DEQUEUE).',
  ),
  GuideEntry(
    term: 'Node',
    tr: 'Düğüm / halka',
    en: 'One piece of a chain or a tree. A chain link knows its NEXT NODE; a tree node knows its LEFT and RIGHT children.',
    trText: 'Bir zincirin ya da ağacın tek bir parçası. Zincir halkası sonraki halkayı (NEXT NODE), ağaç düğümü sol ve sağ çocuklarını (LEFT, RIGHT) bilir.',
  ),
  GuideEntry(
    term: 'NOTHING',
    tr: 'Boş değer',
    en: 'Means "no value": the end of a chain, a missing child, a key not in a map. A value that may be NOTHING must be checked (IS NOT NOTHING) before it is used.',
    trText: '"Değer yok" demektir: zincirin sonu, olmayan bir çocuk, eşlemede bulunmayan bir anahtar. NOTHING olabilecek bir değer kullanılmadan önce kontrol edilmelidir (IS NOT NOTHING).',
  ),
  GuideEntry(
    term: 'Steps and budget',
    tr: 'Adımlar ve bütçe',
    en: 'Every block the program runs costs steps. Some puzzles set a budget: a correct program that needs too many steps shows OPERATION LIMIT.',
    trText: 'Programın çalıştırdığı her blok adım tutar. Bazı bulmacalar bir bütçe koyar: çok fazla adım gerektiren doğru bir program ADIM SINIRI gösterir.',
  ),
];

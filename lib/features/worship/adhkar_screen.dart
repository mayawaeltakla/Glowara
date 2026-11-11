/// أذكار الصباح والمساء: نصوص مع عدد التكرار وعدّاد يومي يتجدد كل يوم.
library glowara.feature.worship.adhkar_screen;

import 'package:flutter/material.dart';
import 'package:glowara/core/models/app_models.dart';
import 'package:glowara/core/state/app_state.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/utils/date_utils.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class Dhikr {
  const Dhikr({required this.text, required this.times, this.source = '', this.note = ''});

  final String text;
  final int times;
  final String source;

  /// فضل الذكر أو ملاحظة تحته.
  final String note;
}

/// أذكار الصباح (النصوص كما زوّدتها المستخدمة).
const List<Dhikr> kMorningAdhkar = <Dhikr>[
  Dhikr(
    text: 'اللّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلاَّ بِمَا شَاء وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَؤُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
    times: 1,
    source: 'آية الكرسي، سورة البقرة ٢٥٥',
  ),
  Dhikr(
    text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ هُوَ ٱللَّهُ أَحَدٌ، ٱللَّهُ ٱلصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ',
    times: 3,
    source: 'سورة الإخلاص',
  ),
  Dhikr(
    text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ ٱلنَّفَّٰثَٰتِ فِى ٱلْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
    times: 3,
    source: 'سورة الفلق',
  ),
  Dhikr(
    text: 'بِسْمِ اللهِ الرَّحْمنِ الرَّحِيم\nقُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ، مَلِكِ ٱلنَّاسِ، إِلَٰهِ ٱلنَّاسِ، مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ، ٱلَّذِى يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ، مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ',
    times: 3,
    source: 'سورة الناس',
  ),
  Dhikr(
    text: 'أَصْبَحْنا وَأَصْبَحَ المُلْكُ لله وَالحَمدُ لله ، لا إلهَ إلاّ اللّهُ وَحدَهُ لا شَريكَ لهُ، لهُ المُلكُ ولهُ الحَمْد، وهُوَ على كلّ شَيءٍ قدير ، رَبِّ أسْأَلُكَ خَيرَ ما في هذا اليوم وَخَيرَ ما بَعْدَه ، وَأَعوذُ بِكَ مِنْ شَرِّ ما في هذا اليوم وَشَرِّ ما بَعْدَه، رَبِّ أَعوذُ بِكَ مِنَ الْكَسَلِ وَسوءِ الْكِبَر ، رَبِّ أَعوذُ بِكَ مِنْ عَذابٍ في النّارِ وَعَذابٍ في القَبْر',
    times: 1,
  ),
  Dhikr(
    text: 'اللّهمَّ أَنْتَ رَبِّي لا إلهَ إلاّ أَنْتَ ، خَلَقْتَني وَأَنا عَبْدُك ، وَأَنا عَلى عَهْدِكَ وَوَعْدِكَ ما اسْتَطَعْت ، أَعوذُ بِكَ مِنْ شَرِّ ما صَنَعْت ، أَبوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبوءُ بِذَنْبي فَاغْفِرْ لي فَإِنَّهُ لا يَغْفِرُ الذُّنوبَ إِلاّ أَنْتَ',
    times: 1,
  ),
  Dhikr(
    text: 'رَضيتُ بِاللهِ رَبَّاً وَبِالإسْلامِ ديناً وَبِمُحَمَّدٍ صلى الله عليه وسلم نَبِيّاً',
    times: 3,
  ),
  Dhikr(
    text: 'اللّهُمَّ إِنِّي أَصبَحْتُ أُشْهِدُك ، وَأُشْهِدُ حَمَلَةَ عَرْشِك ، وَمَلَائِكَتَكَ ، وَجَميعَ خَلْقِك ، أَنَّكَ أَنْتَ اللهُ لا إلهَ إلاّ أَنْتَ وَحْدَكَ لا شَريكَ لَك ، وَأَنَّ ُ مُحَمّداً عَبْدُكَ وَرَسولُك',
    times: 4,
  ),
  Dhikr(
    text: 'اللّهُمَّ ما أَصبَحَ بي مِنْ نِعْمَةٍ أَو بِأَحَدٍ مِنْ خَلْقِك ، فَمِنْكَ وَحْدَكَ لا شريكَ لَك ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْر',
    times: 1,
  ),
  Dhikr(
    text: 'حَسْبِيَ اللّهُ لا إلهَ إلاّ هُوَ عَلَيهِ تَوَكَّلتُ وَهُوَ رَبُّ العَرْشِ العَظيم',
    times: 7,
  ),
  Dhikr(
    text: 'بِسمِ اللهِ الذي لا يَضُرُّ مَعَ اسمِهِ شَيءٌ في الأرْضِ وَلا في السّماءِ وَهوَ السّميعُ العَليم',
    times: 3,
  ),
  Dhikr(
    text: 'اللّهُمَّ بِكَ أَصْبَحنا وَبِكَ أَمْسَينا، وَبِكَ نَحْيا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
    times: 1,
  ),
  Dhikr(
    text: 'أَصْبَحْنا عَلَى فِطْرَةِ الإسْلاَمِ، وَعَلَى كَلِمَةِ الإِخْلاَصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ، وَعَلَى مِلَّةِ أَبِينَا إبْرَاهِيمَ حَنِيفاً مُسْلِماً وَمَا كَانَ مِنَ المُشْرِكِينَ',
    times: 1,
  ),
  Dhikr(
    text: 'سُبْحانَ اللهِ وَبِحَمْدِهِ عَدَدَ خَلْقِه ، وَرِضا نَفْسِه ، وَزِنَةَ عَرْشِه ، وَمِدادَ كَلِماتِه',
    times: 3,
  ),
  Dhikr(
    text: 'اللّهُمَّ عافِني في بَدَني ، اللّهُمَّ عافِني في سَمْعي ، اللّهُمَّ عافِني في بَصَري ، لا إلهَ إلاّ أَنْتَ',
    times: 3,
  ),
  Dhikr(
    text: 'اللّهُمَّ إِنّي أَعوذُ بِكَ مِنَ الْكُفر ، وَالفَقْر ، وَأَعوذُ بِكَ مِنْ عَذابِ القَبْر ، لا إلهَ إلاّ أَنْتَ',
    times: 3,
  ),
  Dhikr(
    text: 'اللّهُمَّ إِنِّي أسْأَلُكَ العَفْوَ وَالعافِيةَ في الدُّنْيا وَالآخِرَة ، اللّهُمَّ إِنِّي أسْأَلُكَ العَفْوَ وَالعافِيةَ في ديني وَدُنْيايَ وَأهْلي وَمالي ، اللّهُمَّ اسْتُرْ عوْراتي وَآمِنْ رَوْعاتي ، اللّهُمَّ احْفَظْني مِن بَينِ يَدَيَّ وَمِن خَلْفي وَعَن يَميني وَعَن شِمالي، وَمِن فَوْقي ، وَأَعوذُ بِعَظَمَتِكَ أَن أُغْتالَ مِن تَحْتي',
    times: 1,
  ),
  Dhikr(
    text: 'يَا حَيُّ يَا قيُّومُ بِرَحْمَتِكَ أسْتَغِيثُ أصْلِحْ لِي شَأنِي كُلَّهُ وَلاَ تَكِلْنِي إلَى نَفْسِي طَرْفَةَ عَيْنٍ',
    times: 3,
  ),
  Dhikr(
    text: 'أَصْبَحْنا وَأَصْبَحْ المُلكُ للهِ رَبِّ العالَمين ، اللّهُمَّ إِنِّي أسْأَلُكَ خَيْرَ هذا اليَوْم ، فَتْحَهُ ، وَنَصْرَهُ ، وَنورَهُ وَبَرَكَتَهُ ، وَهُداهُ ، وَأَعوذُ بِكَ مِنْ شَرِّ ما فيهِ وَشَرِّ ما بَعْدَه',
    times: 1,
  ),
  Dhikr(
    text: 'اللّهُمَّ عالِمَ الغَيْبِ وَالشّهادَةِ فاطِرَ السّماواتِ وَالأرْضِ رَبَّ كلِّ شَيءٍ وَمَليكَه ، أَشْهَدُ أَنْ لا إِلهَ إِلاّ أَنْت ، أَعوذُ بِكَ مِن شَرِّ نَفْسي وَمِن شَرِّ الشَّيْطانِ وَشِرْكِهِ ، وَأَنْ أَقْتَرِفَ عَلى نَفْسي سوءاً أَوْ أَجُرَّهُ إِلى مُسْلِم',
    times: 1,
  ),
];

/// أذكار المساء (النصوص وأعدادها كما زوّدتها المستخدمة).
const List<Dhikr> kEveningAdhkar = <Dhikr>[
  Dhikr(
    text: 'قراءة المعوذتين قل أعوذ برب الفلق قل أعوذ برب الناس و سورة الأخلاص',
    times: 3,
  ),
  Dhikr(
    text: 'قراءة آية الكرسي:\nاللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلاَ يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلاَّ بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ وَلاَ يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيم',
    times: 1,
  ),
  Dhikr(
    text: 'قراءة الآيتين الأخيرتين من سورة البقرة:\nآمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ كُلٌّ آمَنَ بِاللَّهِ وَمَلائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ وَقَالُوا سَمِعْنَا وَأَطَعْنَا غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ ۝لا يُكَلِّفُ اللَّهُ نَفْسًا إِلا وُسْعَهَا لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ رَبَّنَا لا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا رَبَّنَا وَلا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا رَبَّنَا وَلا تُحَمِّلْنَا مَا لا طَاقَةَ لَنَا بِهِ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا أَنْتَ مَوْلانَا فَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِين',
    times: 1,
  ),
  Dhikr(
    text: 'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم',
    times: 3,
  ),
  Dhikr(
    text: 'أعوذ بكلمات الله التامات من شر ما خلق',
    times: 3,
  ),
  Dhikr(
    text: 'رضيت بالله ربا وبالإسلام دينا وبمحمد صلى الله عليه وسلم نبياً',
    times: 3,
  ),
  Dhikr(
    text: 'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم',
    times: 7,
    note: 'من قالها 7 مرات كفاه الله ما أهمه',
  ),
  Dhikr(
    text: 'يا حي يا قيوم برحمتك أستغيث أصلح لي شأني كله ولا تكلني إلى نفسي طرفة عين',
    times: 1,
  ),
  Dhikr(
    text: 'اللهم أنت ربي لا إله إلا أنت خلقتني وأنا عبدك وأنا على عهدك ووعدك ما استطعت أعوذ بك من شر ما صنعت أبوء لك بنعمتك علي وأبوء بذنبي فاغفر لي فإنه لا يغفر الذنوب إلا أنت',
    times: 1,
    note: 'من قالها حينما يمسي مؤمنا بها موقنا بها فمات من ليلته دخل الجنة',
  ),
  Dhikr(
    text: 'اللهم فاطر السماوات والأرض عالم الغيب والشهادة رب كل شي ومليكه أشهد أن لا إله إلا أنت أعوذ بك من شر نفسي ومن شر الشيطان وشركه وان اقترف على نفسي سوءا أو أجره لمسلم',
    times: 1,
  ),
  Dhikr(
    text: 'أمسينا وأمسى الملك لله والحمد لله ، لا اله إلا الله وحده لا شريك له ، له الملك وله الحمد ، وهو على كل شيء قدير ، ربي أسألك خير ما في هذا الليلة وخير ما بعدها ، أعوذ بك من شر ما في هذا الليلة وشر ما بعدها ، ربي أعوذ بك من الكسل وسوء الكبر ، ربي أعوذ بك من عذاب في النار وعذاب في القبر',
    times: 1,
  ),
  Dhikr(
    text: 'اللهم بك أمسينا وبك أصبحنا ، وبك نحيا وبك نموت وإليك المصير',
    times: 1,
  ),
  Dhikr(
    text: 'أمسينا على فطرة الإسلام وعلى كلمة الإخلاص وعلى دين نبينا محمد صلى الله عليه وسلم وعلى ملة أبينا إبراهيم حنيفاً مسلماً وما كان من المشركين',
    times: 1,
  ),
  Dhikr(
    text: 'اللهم إني أسألك العافية في الدنيا والآخرة ، اللهم إني أسألك العفو والعافية في ديني ودنياي وأهلي ومالي ، اللهم أستر عوراتي ، وآمن روعاتي اللهم احفظني من بين يدي ، ومن خلفي وعن يميني ، وعن شمالي ، ومن فوقي ، وأعوذ بعظمتك أن اغتال من تحتي',
    times: 1,
  ),
  Dhikr(
    text: 'لا إله إلا الله وحده لا شريك له ، له الملك ، وله الحمد وهو على كل شيء قدير',
    times: 10,
  ),
  Dhikr(
    text: 'سبحان الله وبحمده',
    times: 100,
    note: 'من قالها (100) مرة حطت خطاياه وإن كانت مثل زبد البحر',
  ),
  Dhikr(
    text: 'اللهم أني أمسيت أشهدك وأشهد حملة عرشك وملائكتك وجميع خلقك انك انت الله لا اله الا انت وحدك لا شريك , وان محمدا عبدك ورسولك',
    times: 4,
  ),
  Dhikr(
    text: 'اللهم ما امسي بي من نعمة او باحد من خلقك , فمنك وحدك لا شريك لك فلك الحمد والشكر',
    times: 1,
  ),
  Dhikr(
    text: 'اللهم عافني في بدني اللهم عافني في سمعي اللهم عافني في بصري لا اله الا انت اللهم اني اعوذ بك من الكفر والفقر , واعوذ بك من عذاب القبر , لا اله الا انت',
    times: 3,
  ),
  Dhikr(
    text: 'امسينا وامسي الملك لله رب العالمين , اللهم اني اسالك خير هذا اليوم فتحه ونصره وبركته وهداه , واعوذ بك من شر ما فيه وشر ما بعده',
    times: 1,
  ),
  Dhikr(
    text: 'اللهم صل وسلم وبارك على نبينا محمد',
    times: 10,
  ),
  Dhikr(
    text: 'اللهم انا نعوذ بك من ان نشرك بك شيئا نعلمه ونستغفرك لما لا نعلمه',
    times: 3,
  ),
  Dhikr(
    text: 'اللهم اني اعوذ بك من الهم والحزن واعوذ بك من العجز والكسل واعوذ بك من الجبن والبخل واعوذ بك من غلبة الدين وقهر الرجال',
    times: 3,
  ),
  Dhikr(
    text: 'أستغفر الله العظيم الذي لا اله الا هو الحي القيوم واتوب اليه',
    times: 3,
  ),
  Dhikr(
    text: 'يارب لك الحمد كما ينبغي لجلال وجهك ولعظيم سلطانك',
    times: 3,
  ),
  Dhikr(
    text: 'اللهم انت ربي لا اله الا انت عليه توكلت وانت رب العرش الكريم ما شاء الله كان , وما لم يشأ لم يكن ولا حول ولا قوة الا بالله العلي العظيم .. اعلم ان الله علي كل شئ قدير , وان الله قد احاط بكل شئ علماً , اللهم اني اعوذ بك من شر نفسي ومن شر كل دابة انت آخذ بناصيتها ان ربي علي صراط مستقيم .',
    times: 1,
  ),
];

/// مفتاح علامة إتمام أذكار اليوم (تقرؤها الشاشة الرئيسية).
String doneFlagKey(bool morning, DateTime day) =>
    'adhkar_done_${morning ? 'morning' : 'evening'}_${dateKey(day)}';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key, required this.morning});

  final bool morning;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final List<Dhikr> _items = widget.morning ? kMorningAdhkar : kEveningAdhkar;
  late List<int> _counts = List<int>.filled(_items.length, 0);
  bool _loaded = false;
  bool _logged = false;

  String get _key =>
      'adhkar_${widget.morning ? 'morning' : 'evening'}_${dateKey(DateTime.now())}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final raw = await AppState.of(context).settings.get<String>(_key);
    if (!mounted) return;
    if (raw != null) {
      final parts = raw.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length == _items.length) setState(() => _counts = parts);
    }
    _logged = _allDone;
  }

  bool get _allDone {
    for (var i = 0; i < _items.length; i++) {
      if (_counts[i] < _items[i].times) return false;
    }
    return true;
  }

  Future<void> _tap(int i) async {
    if (_counts[i] >= _items[i].times) return;
    setState(() => _counts[i]++);
    final state = AppState.of(context);
    await state.settings.set(_key, _counts.join(','));
    if (_allDone && !_logged) {
      _logged = true;
      await state.settings.set(doneFlagKey(widget.morning, DateTime.now()), '1');
      await state.worship.saveReading(
        ReadingLog(
          id: uniqueId(),
          userId: state.userId,
          itemId: widget.morning ? 'adhkar_morning' : 'adhkar_evening',
          completedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _reset() async {
    setState(() {
      _counts = List<int>.filled(_items.length, 0);
      _logged = false;
    });
    final settings = AppState.of(context).settings;
    await settings.set(_key, _counts.join(','));
    await settings.set(doneFlagKey(widget.morning, DateTime.now()), '0');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final done = _counts.asMap().entries.where((e) => e.value >= _items[e.key].times).length;
    return GlowPage(
      title: widget.morning ? 'أذكار الصباح' : 'أذكار المساء',
      actions: <Widget>[
        IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt), tooltip: 'إعادة'),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _allDone ? 'أتممتِ أذكار اليوم، تقبّل الله منك' : 'اضغطي على الذكر لعدّ التكرار',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface),
                      ),
                    ),
                    Text('$done/${_items.length}', style: TextStyle(fontWeight: FontWeight.w700, color: c.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                GlowProgress(value: _items.isEmpty ? 0 : done / _items.length),
                const SizedBox(height: 8),
                Text(
                  'اضغطي على الذكر لعدّ تكراره. يتجدد العدّاد كل يوم.',
                  style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlowCard(
                onTap: () => _tap(i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _items[i].text,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 18, height: 2, color: c.onSurface),
                    ),
                    if (_items[i].note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _items[i].note,
                          style: TextStyle(fontSize: 12, height: 1.6, color: c.primary),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _items[i].source,
                            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _counts[i] >= _items[i].times ? c.success : c.primaryContainer,
                            borderRadius: BorderRadius.circular(GlowRadius.pill),
                          ),
                          child: Text(
                            _counts[i] >= _items[i].times
                                ? '✓'
                                : '${_counts[i]}/${_items[i].times}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _counts[i] >= _items[i].times ? Colors.white : c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

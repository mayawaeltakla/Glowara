/// قسم الدعاء: أدعية زوّدتها صاحبة التطبيق، مع نسخ سريع.
library glowara.feature.worship.dua_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowara/core/theme/app_theme.dart';
import 'package:glowara/core/widgets/glow_widgets.dart';

class Dua {
  const Dua({required this.text, this.intro});

  final String text;
  final String? intro;
}

const List<Dua> kDuas = <Dua>[
  Dua(
    text: 'اللَّهُمَّ اصْرِفْ عَنْ بُيُوتِنَا الْمَرَضَ وَالْهُمُومَ وَالْقَلَقَ وَالْأَحْزَانَ، وَمُنَّ عَلَيْهَا بِالسَّكِينَةِ وَالسِّتْرِ وَالْأَمَانِ يارب',
  ),
  Dua(
    text: 'اللَّهُمَّ لا تَدَعْ لَنَا ذَنْبًا إِلاَّ غَفَرْتَهُ، وَلا هَمًّا إِلاَّ فَرَّجْتَهُ، وَلا دَيْنًا إِلاَّ قَضَيْتَهُ، وَلا مَرِيضاً إِلاَّ شَفَيْتَهُ، وَلا مُبْتَلَى إِلاَّ عَافَيْتَهُ، وَلا ضَالاً إِلاَّ هَدَيْتَهُ، وَلا غَائِباً إِلاَّ رَدَدْتَهُ، وَلا مَظْلُوماً إِلاَّ نَصَرْتَهُ، وَلا أَسِيراً إِلاَّ فَكَكْتَهُ، وَلا مَيِّتاً إِلاَّ رَحِمْتَهُ، وَلا حَاجَةً لَنَا فِيهَا صَلاحٌ وَلَكَ فِيهَا رِضاً إِلاَّ قَضَيْتَهَا وَيَسَّرْتَهَا بِفَضْلِكَ يَا أَكْرَمَ الأَكْرَمِينَ.',
  ),
  Dua(
    text: 'أستودعُ اللهَ أولادي: روحًا وجسدًا مِنْ شرِّ حاسدٍ إذا حسد.\nأستودعُ الله أجسادَهم؛ فأبعدْ عنهم التعبَ والمرضَ.\nأستودعُ الله أخلاقَهم ، فاجعلْهم آيةً في حُسنِ الخُلُق.\nأستودعُ الله أرزاقَهم؛ فارزقْهم حلالًا طيِّبًا، ولا تحوجهم لأحدٍ.يا رب.',
  ),
  Dua(
    text: 'اللهم سخر لي جنود الارض وملائكة السماء وكل من وليته امري وارزقني حظ الدنيا ونعيم الاخرة ويسر لي كل امر عسير ، وقل لما اريد كن ليكون بحولك وقوتك ورحمتك ، يااارب ايام جميلة واخبار مفرحة وراحة بال وتوفيق من عندك انك على كل شي قدير',
  ),
  Dua(
    text: 'اللهم يامن شفيت ايوب وكشفت ضر عن يعقوب اشفي كل مريض يتألم ولايتكلم ولايعلم بحاله الا انت',
  ),
  Dua(
    text: 'اللهم اني اسالك الشفاء لكل روح عجزت عن النوم بسبب المرض ، ربي ارح ثم هون ثم اشفي كل نفس لايعلم بوجعها الا انت انك على كل شي قدير يارب',
  ),
  Dua(
    intro: 'عودي نفسك كل صباح أن تقولي',
    text: 'اللهم إني أسألك خير ما في هذا اليوم ، فَتْحَه وَنَصرَه ونورَه وَبَرَكته وَهُداهُ " استودعُ الله الذي لا تضيع ودائعه ديني ونفسي وأمانتي وخواتيم عملي وأبنائي وأهلي وأحبتي وبيتي ومالي وجميع ما أنعم الله به عليّ "',
  ),
  Dua(
    text: 'اللهم جملني بقلب رحيم وعقل حكيم ونفس صبوره، يارب اجعل بسمتي عاده وحديثي عباده وحياتي سعاده وخاتمتي شهاده',
  ),
  Dua(
    text: 'اللهم اغفر لي ولمن اغتبتُه و ظلمته وأسأتَ إليه وتجاوز عنّي وعنه.',
  ),
  Dua(
    intro: 'أربع وثلاثون بلاءً كان يستعيذ منها النبي ﷺ',
    text: 'اللَّهُمّ إنِّي أعُوذُ بِكَ مِن: ١- العَجْزِ، ٢- والكَسَلِ، ٣- والجُبْنِ، ٤- والبُخْلِ، ٥- والهَرَمِ، ٦- والقَسْوَةِ، ٧- والغَفْلَةِ، ٨- والعَيْلَةِ، ٩- والذِّلَّةِ، ١٠- والمَسْكَنَةِ.\n'
        'وأعُوذُ بِكَ من: ١١- الفقر، ١٢- والكُفْرِ، ١٣- والشِّرْك، ١٤- والفُسُوقِ، ١٥- والشِّقاقِ، ١٦- والنِّفاقِ، ١٧- والسُّمْعَةِ، ١٨- والرِّياءِ.\n'
        'وأعُوذُ بِكَ من: ١٩- الصمم، ٢٠- والبَكَم، ٢١- والجُنُون، ٢٢- والجُذامِ، ٢٣- والبَرَص، ٢٤- وَسَيِّىءِ الأَسْقامِ.\n'
        'وأعوذ بك من: ٢٥- غلبة الدَين، ٢٦- وقهر الرجال.\n'
        'وأعوذ بك من: ٢٧- زوال نِعْمَتِك، ٢٨- و تَحوُّلِ عافِيَتِك، ٢٩- وفُجَاءَةِ نِقْمَتِك، ٣٠- و جَميعِ سَخَطِك.\n'
        'وأعوذ بك من: ٣١- جَهْدِ الْبَلاَءِ، ٣٢- وَدَرَكِ الشَّقَاءِ، ٣٣- وَسُوءِ الْقَضَاءِ، ٣٤- وَشَمَاتَةِ الأَعْدَاءِ.\n'
        'واعوذ بك من فتنة الدنيا ومن فتنة القبر',
  ),
];

class DuaScreen extends StatelessWidget {
  const DuaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return GlowPage(
      title: 'الدعاء',
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: kDuas.length,
        itemBuilder: (context, i) {
          final dua = kDuas[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (dua.intro != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        dua.intro!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary),
                      ),
                    ),
                  Text(
                    dua.text,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: 17, height: 2, color: c.onSurface),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'نسخ',
                      icon: Icon(Icons.copy_rounded, size: 20, color: c.onSurfaceVariant),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: dua.text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النسخ')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

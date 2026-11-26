/// نماذج التغذية المتوازنة. بلا سعرات ولا أوزان ولا أهداف وزن. كل ما هنا
/// اقتراحات عامة وخطط تكتبها المستخدمة بنفسها.
library glowara.models.nutrition;

/// مجموعات الطعام الخمس (علامات اختيارية على الوجبة).
const List<String> kFoodGroups = <String>['vegetables', 'fruit', 'grains', 'protein', 'dairy'];

/// مفتاح نص اسم كل مجموعة طعام.
const Map<String, String> kFoodGroupLabelKeys = <String, String>{
  'vegetables': 'ngVegetables',
  'fruit': 'ngFruit',
  'grains': 'ngGrains',
  'protein': 'ngProtein',
  'dairy': 'ngDairy',
};

/// وجبات الخطة الأسبوعية.
const List<String> kPlanMealTypes = <String>['breakfast', 'lunch', 'dinner', 'snack'];

const int kPlanCellMax = 120;

/// خطة وجبات أسبوع. المفتاح `<userId>_<weekStart>`، والأيام بمفتاح تاريخ صريح.
class MealPlan {
  const MealPlan({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    this.days = const <String, Map<String, String>>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String weekStart;
  final String weekEnd;

  /// تاريخ (`YYYY-MM-DD`) -> نوع الوجبة -> نص الخطة.
  final Map<String, Map<String, String>> days;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String idFor(String userId, String weekStart) => '${userId}_$weekStart';

  String? cell(String day, String mealType) => days[day]?[mealType];

  bool get isBlank => days.values.every((m) => m.isEmpty);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'days': days,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory MealPlan.fromJson(Map<String, dynamic> j) {
    DateTime when(Object? v) => (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();
    final days = <String, Map<String, String>>{};
    final raw = j['days'];
    if (raw is Map) {
      raw.forEach((Object? day, Object? meals) {
        if (day is! String || meals is! Map) return;
        final cells = <String, String>{};
        meals.forEach((Object? type, Object? text) {
          if (type is String && text is String && text.isNotEmpty) cells[type] = text;
        });
        if (cells.isNotEmpty) days[day] = cells;
      });
    }
    return MealPlan(
      id: j['id'] as String,
      userId: j['userId'] as String,
      weekStart: j['weekStart'] as String,
      weekEnd: j['weekEnd'] as String,
      days: days,
      createdAt: when(j['createdAt']),
      updatedAt: when(j['updatedAt']),
    );
  }
}

/// ملخص هادئ لأسبوع: ما سجّلته فقط، بلا درجات ولا أهداف. لا يحمل نصوص الوجبات.
class NutritionWeekSummary {
  const NutritionWeekSummary({
    this.daysWithMeals = 0,
    this.mealsLogged = 0,
    this.groupsSeen = const <String>{},
    this.waterDays = 0,
  });

  final int daysWithMeals;
  final int mealsLogged;
  final Set<String> groupsSeen;
  final int waterDays;

  bool get isEmpty => mealsLogged == 0 && waterDays == 0;
}

/// اقتراح وجبة عام للإلهام: ليس نصيحة طبية ولا حمية، بلا سعرات ولا كميات.
class MealIdea {
  const MealIdea(this.id, this.mealType, this.groups, this.ar, this.en);

  final String id;
  final String mealType;
  final List<String> groups;
  final String ar;
  final String en;

  String text(String locale) => locale == 'ar' ? ar : en;
}

const List<MealIdea> kMealIdeas = <MealIdea>[
  MealIdea('b1', 'breakfast', <String>['grains', 'protein', 'vegetables'], 'خبز أسمر مع بيض مسلوق وخيار وبندورة', 'Whole-grain bread with a boiled egg, cucumber and tomato'),
  MealIdea('b2', 'breakfast', <String>['dairy', 'vegetables', 'grains'], 'لبنة مع زيت زيتون وخضار طازجة وخبز', 'Labneh with olive oil, fresh vegetables and bread'),
  MealIdea('b3', 'breakfast', <String>['grains', 'dairy', 'fruit'], 'شوفان بالحليب مع تفاح وقرفة', 'Oats with milk, apple and cinnamon'),
  MealIdea('b4', 'breakfast', <String>['protein', 'grains'], 'فول بالزيت والليمون مع خبز', 'Fava beans with olive oil and lemon, with bread'),
  MealIdea('b5', 'breakfast', <String>['dairy', 'fruit', 'protein'], 'زبادي مع فاكهة وحفنة مكسرات', 'Yogurt with fruit and a handful of nuts'),
  MealIdea('l1', 'lunch', <String>['grains', 'protein', 'vegetables'], 'أرز مع دجاج مشوي وسلطة خضار', 'Rice with grilled chicken and a vegetable salad'),
  MealIdea('l2', 'lunch', <String>['protein', 'grains', 'vegetables'], 'شوربة عدس مع خبز وسلطة', 'Lentil soup with bread and a salad'),
  MealIdea('l3', 'lunch', <String>['protein', 'vegetables', 'grains'], 'سمك مشوي مع خضار مطبوخة وبطاطا', 'Grilled fish with cooked vegetables and potatoes'),
  MealIdea('l4', 'lunch', <String>['grains', 'protein', 'vegetables', 'dairy'], 'مجدرة مع سلطة وزبادي', 'Mujaddara (lentils and rice) with salad and yogurt'),
  MealIdea('l5', 'lunch', <String>['grains', 'vegetables', 'dairy'], 'معكرونة بصلصة الخضار وجبنة', 'Pasta with vegetable sauce and cheese'),
  MealIdea('d1', 'dinner', <String>['protein', 'vegetables', 'grains'], 'عجّة بيض بالخضار مع خبز', 'Vegetable omelette with bread'),
  MealIdea('d2', 'dinner', <String>['protein', 'vegetables', 'grains'], 'سلطة حمّص وخضار مع خبز', 'Chickpea and vegetable salad with bread'),
  MealIdea('d3', 'dinner', <String>['protein', 'vegetables'], 'دجاج مع خضار مشوية', 'Chicken with roasted vegetables'),
  MealIdea('d4', 'dinner', <String>['vegetables', 'dairy', 'grains'], 'شوربة خضار مع جبنة وخبز', 'Vegetable soup with cheese and bread'),
  MealIdea('d5', 'dinner', <String>['protein', 'vegetables', 'grains'], 'تونة مع سلطة وخبز محمص', 'Tuna with salad and toasted bread'),
  MealIdea('s1', 'snack', <String>['fruit', 'protein'], 'تفاحة وحفنة لوز', 'An apple and a handful of almonds'),
  MealIdea('s2', 'snack', <String>['dairy'], 'زبادي سادة', 'Plain yogurt'),
  MealIdea('s3', 'snack', <String>['vegetables', 'protein'], 'جزر وخيار مع حمّص', 'Carrot and cucumber sticks with hummus'),
  MealIdea('s4', 'snack', <String>['fruit'], 'موزة', 'A banana'),
  MealIdea('s5', 'snack', <String>['dairy', 'grains'], 'جبنة مع خبز', 'Cheese with bread'),
];

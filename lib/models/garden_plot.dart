import 'plant.dart';

/// One cell in the garden grid.
class GardenPlot {
  final String id;
  final int index;        // 0-based position in the grid
  final Plant? plant;     // null = empty
  final int carePoints;   // 0-100: accumulates toward next growth stage

  const GardenPlot({
    required this.id,
    required this.index,
    this.plant,
    this.carePoints = 0,
  });

  bool get isEmpty => plant == null;
  bool get hasPlant => plant != null;

  GardenPlot withPlant(Plant? p) =>
      GardenPlot(id: id, index: index, plant: p, carePoints: carePoints);

  GardenPlot withCare(int c) =>
      GardenPlot(id: id, index: index, plant: plant, carePoints: c);

  GardenPlot copyWith({Plant? plant, int? carePoints}) => GardenPlot(
        id: id,
        index: index,
        plant: plant ?? this.plant,
        carePoints: carePoints ?? this.carePoints,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'index': index,
        'plant': plant?.toJson(),
        'carePoints': carePoints,
      };

  factory GardenPlot.fromJson(Map<String, dynamic> j) => GardenPlot(
        id: j['id'] as String,
        index: (j['index'] as num).toInt(),
        plant: j['plant'] != null
            ? Plant.fromJson(j['plant'] as Map<String, dynamic>)
            : null,
        carePoints: (j['carePoints'] as num?)?.toInt() ?? 0,
      );
}

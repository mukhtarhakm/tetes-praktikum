import 'models.dart';

class BrewSessionProgress {
  const BrewSessionProgress(this.plan, this.elapsedSeconds);

  static const maxDrawdownSeconds = 600;

  final BrewPlan plan;
  final int elapsedSeconds;

  int get pourDurationSeconds =>
      plan.stages.fold(0, (sum, stage) => sum + stage.durationS);

  bool get isDrawdown => elapsedSeconds >= pourDurationSeconds;

  int get stageIndex {
    var start = 0;
    for (var i = 0; i < plan.stages.length; i++) {
      start += plan.stages[i].durationS;
      if (elapsedSeconds < start) return i;
    }
    return plan.stages.length - 1;
  }

  int get stageStartSeconds => plan.stages
      .take(stageIndex)
      .fold(0, (sum, stage) => sum + stage.durationS);

  int get stageElapsedSeconds => (elapsedSeconds - stageStartSeconds).clamp(
    0,
    plan.stages[stageIndex].durationS,
  );

  double? get stageProgress => isDrawdown
      ? null
      : stageElapsedSeconds / plan.stages[stageIndex].durationS;

  int get drawdownElapsedSeconds =>
      isDrawdown ? elapsedSeconds - pourDurationSeconds : 0;

  double cumulativeWaterAt(int index) => plan.customStages == null
      ? plan.stages[index].waterG
      : plan.stages
            .take(index + 1)
            .fold<double>(0, (sum, stage) => sum + stage.waterG);
}

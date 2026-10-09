enum PollingRate {
  hz125(125),
  hz250(250),
  hz500(500),
  hz1000(1000);

  const PollingRate(this.hz);

  final int hz;

  static const factoryDefault = PollingRate.hz1000;
}

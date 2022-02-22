class TrafficLight {
  color: TrafficLightColor;

  constructor() {
    this.color = TrafficLightColor.Red;
  }

  getState(): TrafficLightColor {
    return this.color;
  }

  turnGreen() {
    this.color = TrafficLightColor.Green;
  }
}

enum TrafficLightColor {
  Red = "red",
  Yellow = "yellow",
  Green = "green",
}

const light = new TrafficLight();
console.log(light.getState());
light.turnGreen();
console.log(light.getState());

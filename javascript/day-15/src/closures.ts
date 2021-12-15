function main() {
  let closure = () => {
    console.log("Hi! I'm in a closure");
  };
  closure();

  let double = (num: number) => num + num;
  let num = 4;
  console.log(`${num} + ${num} = ${double(num)}`);

  let name = "Rebecca";
  closure = () => {
    console.log(`Hi, ${name}.`);
  };
  closure();

  let counter = 0;
  closure = () => {
    counter += 1;
    console.log(`This closure has a counter. I've been run ${counter} times.`);
  };
  closure();
  closure();
  closure();
  console.log(`The closure was called a total of ${counter} times`);

  let adder = (left: number, right: number) => {
    console.log(`${left} + ${right} is ${left + right}`);
    left + right;
  };
  adder(4, 5);

  let plusTwo = makeAdder(2);
  plusTwo(23);

  let timesTwo = (i: number) => i * 2;
  let doublePlusTwo = compose(plusTwo, timesTwo);
  console.log(`${10} * 2 + 2 = ${doublePlusTwo(10)}`);

  let fnRef = regularFunction;
  fnRef();

  let square = new DynamicBehavior((num: number) => num * num);
  console.log(`${5} squared is ${square.run(5)}`);
}

function regularFunction() {
  console.log("I'm a regular function");
}

function makeAdder(left: number): (left: number) => number {
  return (right: number) => {
    console.log(`${left} + ${right} is ${left + right}`);
    return left + right;
  };
}

function compose<T>(f: (left: T) => T, g: (left: T) => T): (left: T) => T {
  return (right: T) => f(g(right));
}

class DynamicBehavior<T> {
  closure: (num: T) => T;
  constructor(closure: (num: T) => T) {
    this.closure = closure;
  }
  run(arg: T): T {
    return this.closure(arg);
  }
}

main();

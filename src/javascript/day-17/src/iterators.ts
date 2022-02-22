function main() {
  filter();
  find();
  forEach();
  join();
  map();
  push_pop();
  shift_unshift();
}

function filter() {
  let numbers = [1, 2, 3, 4, 5];
  let even = numbers.filter((x) => x % 2 === 0);
  console.log(even);
}

function find() {
  let numbers = [1, 2, 3, 4, 5];
  let firstEven = numbers.find((x) => x % 2 === 0);
  console.log(firstEven);
}

function forEach() {
  let numbers = [1, 2, 3];
  numbers.forEach((x) => console.log(x));
}

function join() {
  let names = ["Sam", "Janet", "Hunter"];
  let csv = names.join(",");
  console.log(csv);
}

function map() {
  let list = [1, 2, 3];
  let doubled = list.map((x) => x * 2);
  console.log(doubled);
}

function push_pop() {
  let list = [1, 2];
  list.push(3);
  console.log(list.pop());
  console.log(list.pop());
  console.log(list.pop());
  console.log(list.pop());
}

function shift_unshift() {
  let list = [1, 2];
  list.unshift(0);
  console.log(list.shift());
  console.log(list.shift());
  console.log(list.shift());
  console.log(list.shift());
}

main();

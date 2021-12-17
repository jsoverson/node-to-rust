function main() {
  for_common();
  for_in();
  for_of();
  while_not_done();
  while_true();
  labels();
}

function for_common() {
  let max = 4;
  for (let i = 0; i < max; i++) {
    console.log(i);
  }
}

function for_in() {
  let obj: any = {
    key1: "value1",
    key2: "value2",
  };
  for (let prop in obj) {
    console.log(`${prop}: ${obj[prop]}`);
  }
}

function for_of() {
  let numbers = [1, 2, 3, 4, 5];
  for (let number of numbers) {
    console.log(number);
  }
}

function while_not_done() {
  let obj = {
    data: ["a", "b", "c"],
    doWork() {
      return this.data.pop();
    },
  };
  let data;
  while ((data = obj.doWork())) {
    console.log(data);
  }
}

function while_true() {
  let n = 0;

  while (true) {
    n++;
    if (n > 3) break;
  }
  console.log(`Finished. n=${n}`);
}

function labels() {
  console.log("Start");
  outer: while (true) {
    while (true) {
      break outer;
    }
  }
  console.log("Finished");
}

main();

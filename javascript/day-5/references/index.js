function actOnString(string) {
  string += " What a nice day.";
  console.log(`String in function: ${string}`);
}

const stringValue = "Hello!";
console.log(`String before function: ${stringValue}`);
actOnString(stringValue);
console.log(`String after function: ${stringValue}\n`);

function actOnNumber(number) {
  number++;
  console.log(`Number in function: ${number}`);
}

const numberValue = 2000;
console.log(`Number before function: ${numberValue}`);
actOnNumber(numberValue);
console.log(`Number after function: ${numberValue}\n`);

function actOnObject(object) {
  object.firstName = "Samuel";
  object.lastName = "Clemens";
  console.log(`Object in function: ${objectValue}`);
}

const objectValue = {
  firstName: "Jane",
  lastName: "Doe",
};
objectValue.toString = function () {
  return `${this.firstName} ${this.lastName}`;
};
console.log(`Object before function: ${objectValue}`);
actOnObject(objectValue);
console.log(`Object after function: ${objectValue}`);

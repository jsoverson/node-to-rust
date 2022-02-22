const utilityMixin = {
  prettyPrint() {
    console.log(JSON.stringify(this, null, 2));
  },
};

class Person {
  constructor(first, last) {
    this.firstName = first;
    this.lastName = last;
  }
}

function mixin(base, mixer) {
  Object.assign(base.prototype, mixer);
}

mixin(Person, utilityMixin);

const author = new Person("Jarrod", "Overson");
author.prettyPrint();

fn main() {
    apples();
    vec();
}

fn add_numbers(left: i64, right: i64) -> i64 {
    left + right
}

fn apples() {
    let apples = 6;
    let message = if apples > 10 {
        "Lots of apples"
    } else if apples > 4 {
        "A few apples"
    } else {
        "Not many apples at all"
    };

    println!("{}", message)
}

fn vec() {
    let mut numbers = vec![1, 2, 3, 4, 5];
    numbers.push(7);
    println!("{:?}", numbers);
}

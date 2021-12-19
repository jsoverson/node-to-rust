#[tokio::main]
async fn main() {
    println!("One");
    let future = prints_two();
    println!("Three");
    // Uncomment and move the following line around to see how the behavior changes.
    // future.await;
}

async fn prints_two() {
    println!("Two")
}

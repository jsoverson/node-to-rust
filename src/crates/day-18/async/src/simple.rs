#[tokio::main]
async fn main() {
    let msg = regular_fn();
    println!("{}", msg);

    let msg = async_fn().await;
    println!("{}", msg);
}

fn regular_fn() -> String {
    "I'm a regular function".to_owned()
}

// The return value here is actually: impl Future<Output = String>
async fn async_fn() -> String {
    "I'm an async function".to_owned()
}

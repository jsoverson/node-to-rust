#[tokio::main]
async fn main() {
    let msg = "Hello world".to_owned();

    let async_block = || async {
        println!("{}", msg);
    };
    async_block().await;

    let closure = || async {
        println!("{}", msg);
    };
    closure().await;
}

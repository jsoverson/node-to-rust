use std::sync::Arc;

use parking_lot::RwLock;

#[tokio::main]
async fn main() {
    let treasure = RwLock::new(Treasure { dubloons: 100 });
    tokio::task::spawn(empty_treasure_and_party(&treasure)).await;
}

async fn empty_treasure_and_party(treasure: &RwLock<Treasure>) {
    let mut lock = treasure.write();
    lock.dubloons = 0;

    // Await an async function
    pirate_party().await;
} // lock goes out of scope here

async fn pirate_party() {}

#[derive(Debug)]
struct Treasure {
    dubloons: u32,
}

#[derive(Clone, Debug)]
struct TreasureMap {
    treasure: Arc<RwLock<Treasure>>,
}

impl TreasureMap {
    fn new(treasure: Arc<RwLock<Treasure>>) -> Self {
        TreasureMap { treasure }
    }
}

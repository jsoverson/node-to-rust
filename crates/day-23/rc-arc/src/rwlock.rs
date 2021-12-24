use std::sync::Arc;

use parking_lot::RwLock;

fn main() {
    let booty = Arc::new(RwLock::new(Treasure { dubloons: 1000 }));

    let my_map = TreasureMap::new(booty);

    println!("My TreasureMap before: {:?}", my_map);

    let your_map = my_map.clone();
    let sender = std::thread::spawn(move || {
        {
            let mut treasure = your_map.treasure.write();
            treasure.dubloons = 0;
        }
        println!("Treasure emptied!");
        println!("Your TreasureMap after {:?}", your_map);
    });
    sender.join();

    println!("My TreasureMap after: {:?}", my_map);
}

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

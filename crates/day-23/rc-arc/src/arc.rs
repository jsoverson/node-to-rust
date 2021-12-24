use std::sync::Arc;

fn main() {
    let booty = Arc::new(Treasure { dubloons: 1000 });

    let my_map = TreasureMap::new(booty);

    let your_map = my_map.clone();
    let sender = std::thread::spawn(move || {
        println!("Map in thread {:?}", your_map);
    });
    println!("{:?}", my_map);

    sender.join();
}

#[derive(Debug)]
struct Treasure {
    dubloons: u32,
}

#[derive(Clone, Debug)]
struct TreasureMap {
    treasure: Arc<Treasure>,
}

impl TreasureMap {
    fn new(treasure: Arc<Treasure>) -> Self {
        TreasureMap { treasure }
    }
}
